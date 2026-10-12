// GPL-3.0. Serialized theme commits; pointer/UI work lives in other processes.
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <libproc.h>
#include <signal.h>
#include <stdatomic.h>
#include "native_ipc.h"
#include "theme_catalog.h"

static const char *themePort = "com.denis.sketchybar.native_theme";
static NSString *directory, *committed, *pendingSelection;
static NSArray *catalog;
static NSMutableDictionary *selection;
static NSLock *selectionLock;
static NSAppleScript *toggleScript, *darkScript, *lightScript;
static atomic_uint requests;
static pid_t barPID;

static NSString *system_mode(void) {
  CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  id value = CFBridgingRelease(CFPreferencesCopyValue(CFSTR("AppleInterfaceStyle"),
      kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
  return [value isEqual:@"Dark"] ? @"dark" : @"light";
}

static BOOL write_text(NSString *path, NSString *text) {
  if ([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] isEqual:text]) return YES;
  NSError *error = nil;
  if ([text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) return YES;
  fprintf(stderr, "Theme write: %s\n", error.localizedDescription.UTF8String);
  return NO;
}

static BOOL write_json(NSString *path, id value) {
  NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:NULL];
  if ([[NSData dataWithContentsOfFile:path] isEqual:data]) return YES;
  return data && [data writeToFile:path atomically:YES];
}

static BOOL export_palette(NSString *mode) {
  NSDictionary *theme = rice_theme(catalog, selection[mode]);
  NSDictionary *palette = rice_theme_palette(theme);
  NSMutableString *shell = [NSMutableString stringWithFormat:@"# Generated from themes/catalog.json.\nTHEME_MODE=%@\nTHEME_ID=%@\n", mode, theme[@"id"]];
  for (NSString *key in [[palette allKeys] sortedArrayUsingSelector:@selector(compare:)])
    [shell appendFormat:@"%@=%@\n", key, palette[key]];
  return write_text([NSString stringWithFormat:@"/tmp/rice_palette_%u_%@.sh", getuid(), mode], shell);
}

static BOOL processes(const char *name, int signalNumber) {
  int count = proc_listallpids(NULL, 0);
  if (count <= 0) return NO;
  pid_t *pids = calloc((size_t)count + 128, sizeof(pid_t));
  count = proc_listallpids(pids, (count + 128) * (int)sizeof(pid_t));
  BOOL found = NO;
  for (int i = 0; i < count; i++) {
    char process[PROC_PIDPATHINFO_MAXSIZE] = {0};
    if (pids[i] > 1 && proc_name(pids[i], process, sizeof(process)) > 0 && !strcmp(process, name)) {
      found = YES;
      if (signalNumber) kill(pids[i], signalNumber);
    }
  }
  free(pids);
  return found;
}

static void notify(NSString *name, NSDictionary *info) {
  [NSDistributedNotificationCenter.defaultCenter postNotificationName:name object:@"com.denis.rice" userInfo:info deliverImmediately:YES];
}

static void sync_theme(BOOL force) {
  if (force) {
    selection = rice_theme_selection(directory, catalog);
    if (!export_palette(@"dark") || !export_palette(@"light")) return;
  }
  NSString *mode = system_mode();
  NSDictionary *theme = rice_theme(catalog, selection[mode]);
  if (!theme || (!force && [theme[@"id"] isEqual:committed])) return;
  NSDictionary *palette = rice_theme_palette(theme);
  NSString *ghostty = [[directory stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"ghostty/theme-mode"];
  NSString *override = [NSString stringWithFormat:@"theme = %@\n", theme[@"ghostty"]];
  BOOL reload = ![[NSString stringWithContentsOfFile:ghostty encoding:NSUTF8StringEncoding error:NULL] isEqual:override];
  if (!export_palette(mode) || !write_text(ghostty, override) ||
      !write_text([NSString stringWithFormat:@"/tmp/sketchybar_theme_mode_%u", getuid()], [mode stringByAppendingString:@"\n"]) ||
      !write_json(rice_theme_state_path(), @{@"id":theme[@"id"], @"name":theme[@"name"], @"mode":mode, @"neovim":theme[@"neovim"]})) {
    notify(@"RiceThemeApplyFailed", @{@"message":@"Could not write the theme configuration."}); return;
  }
  NSMutableDictionary *event = [palette mutableCopy];
  event[@"SENDER"] = @"native_theme_palette";
  event[@"MODE"] = mode;
  if (!rice_post("com.denis.sketchybar.native_motion", event)) {
    notify(@"RiceThemeApplyFailed", @{@"message":@"The bar is restarting. Please try again."}); return;
  }
  if (reload) processes("ghostty", SIGUSR2);
  if (![committed isEqual:theme[@"id"]]) processes("nvim", SIGUSR1);
  if (processes("borders", 0)) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/opt/homebrew/bin/borders"];
    task.arguments = rice_border_arguments(theme, NO);
    task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
    task.standardError = NSFileHandle.fileHandleWithNullDevice;
    [task launchAndReturnError:NULL];
  }
  committed = theme[@"id"];
  notify(@"RiceThemeDidChange", @{@"id":committed, @"mode":mode});
  fprintf(stderr, "Theme committed: %s (%s)\n", committed.UTF8String, mode.UTF8String);
}

static BOOL execute(NSAppleScript *script) {
  NSDictionary *error = nil;
  if ([script executeAndReturnError:&error]) return YES;
  fprintf(stderr, "Appearance Automation: %s\n", error.description.UTF8String);
  notify(@"RiceThemeApplyFailed", @{@"message":@"Allow Appearance automation in System Settings → Privacy & Security → Automation."});
  return NO;
}

static void select_theme(void) {
  [selectionLock lock];
  NSString *identifier = pendingSelection;
  pendingSelection = nil;
  [selectionLock unlock];
  NSDictionary *theme = rice_theme(catalog, identifier);
  if (!theme) return;
  NSString *old = selection[theme[@"mode"]];
  // Save the per-appearance choice at selection time, not after bar/terminal
  // updates. A service restart or missed appearance notification cannot lose it.
  if (!rice_remember_theme(directory, catalog, selection, identifier)) {
    notify(@"RiceThemeApplyFailed", @{@"message":@"Could not save your theme choice. Check the rice folder permissions."}); return;
  }
  if (![system_mode() isEqual:theme[@"mode"]] && !execute([theme[@"mode"] isEqual:@"dark"] ? darkScript : lightScript)) {
    if (!rice_remember_theme(directory, catalog, selection, old))
      notify(@"RiceThemeApplyFailed", @{@"message":@"Could not restore the previous theme preference."});
    return;
  }
  if ([identifier isEqual:committed]) {
    notify(@"RiceThemeDidChange", @{@"id":committed, @"mode":theme[@"mode"]}); return;
  }
  // Same-appearance selections do not emit a macOS appearance notification.
  sync_theme(NO);
}

int main(int argc, char **argv) {
  @autoreleasepool {
    const char *config = getenv("CONFIG_DIR");
    directory = config && *config ? @(config) : [NSHomeDirectory() stringByAppendingPathComponent:@".config/sketchybar"];
    catalog = rice_themes(directory);
    if (!catalog) { fprintf(stderr, "Invalid theme catalog\n"); return 1; }
    selection = rice_theme_selection(directory, catalog);
    selectionLock = [NSLock new];
    if (argc == 2 && (!strcmp(argv[1], "--list") || !strcmp(argv[1], "--export-palettes"))) {
      if (!strcmp(argv[1], "--export-palettes")) return export_palette(@"dark") && export_palette(@"light") ? 0 : 1;
      NSData *data = [NSJSONSerialization dataWithJSONObject:catalog options:NSJSONWritingPrettyPrinted error:NULL];
      fwrite(data.bytes, 1, data.length, stdout); return 0;
    }
    if (argc == 3 && (!strcmp(argv[1], "--plan") || !strcmp(argv[1], "--border-args"))) {
      NSString *identifier = @(argv[2]);
      NSDictionary *theme = rice_theme(catalog, selection[identifier] ?: identifier);
      if (!theme) return 2;
      if (!strcmp(argv[1], "--border-args")) {
        for (NSString *argument in rice_border_arguments(theme, YES)) puts(argument.UTF8String);
        return 0;
      }
      NSData *data = [NSJSONSerialization dataWithJSONObject:rice_theme_palette(theme) options:0 error:NULL];
      fwrite(data.bytes, 1, data.length, stdout); return 0;
    }
    if (argc == 3 && !strcmp(argv[1], "--select")) {
      if (!rice_theme(catalog, @(argv[2]))) return 2;
      return rice_post(themePort, @{@"SENDER":@"--select", @"ID":@(argv[2])}) ? 0 : 1;
    }
    if (argc == 2 && (!strcmp(argv[1], "--toggle") || !strcmp(argv[1], "--sync")))
      return rice_post(themePort, @{@"SENDER":@(argv[1])}) ? 0 : 1;
    BOOL daemon = argc == 3 && !strcmp(argv[1], "--run");
    if (argc != 3 || (strcmp(argv[1], "--ensure") && !daemon)) return 2;
    barPID = (pid_t)strtol(argv[2], NULL, 10);
    if (barPID <= 1) return 2;
    if (!daemon && rice_post(themePort, @{@"SENDER":@"--rebind", @"BAR_PID":@(argv[2])})) return 0;
    if (!daemon) {
      char *args[] = {argv[0], "--run", argv[2], NULL};
      pid_t child = fork();
      if (child < 0) return 1;
      // Foundation may start dispatch threads while reading the catalog. A
      // fresh exec is essential before invoking CoreServices/AppleScript.
      if (!child) { setsid(); execv(argv[0], args); _exit(127); }
      for (int i = 0; i < 200; i++) {
        mach_port_t ready = rice_lookup(themePort);
        if (ready) { mach_port_deallocate(mach_task_self(), ready); return 0; }
        usleep(10000);
      }
      return 1;
    }
    freopen("/dev/null", "r", stdin);
    freopen("/dev/null", "w", stdout);
    NSString *log = [NSString stringWithFormat:@"/tmp/sketchybar_native_theme_%u.log", getuid()];
    freopen(log.UTF8String, "a", stderr);
    setvbuf(stderr, NULL, _IONBF, 0);
    NSString *prefix = @"tell application \"System Events\" to tell appearance preferences to set dark mode to ";
    toggleScript = [[NSAppleScript alloc] initWithSource:[prefix stringByAppendingString:@"not dark mode"]];
    darkScript = [[NSAppleScript alloc] initWithSource:[prefix stringByAppendingString:@"true"]];
    lightScript = [[NSAppleScript alloc] initWithSource:[prefix stringByAppendingString:@"false"]];
    for (NSAppleScript *script in @[toggleScript, darkScript, lightScript]) {
      NSDictionary *error = nil;
      if (![script compileAndReturnError:&error]) {
        fprintf(stderr, "Appearance script: %s\n", error.description.UTF8String); return 1;
      }
    }
    mach_port_t port = rice_register(themePort);
    if (!port) return 1;
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"AppleInterfaceThemeChangedNotification"
      object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { (void)note; sync_theme(NO); }];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
      for (;;) {
        struct mach_buffer buffer;
        mach_receive_message(port, &buffer, true);
        if (!buffer.message.descriptor.address) continue;
        if (buffer.message.descriptor.size == 2 && *(char *)buffer.message.descriptor.address == 'k') {
          mach_msg_destroy(&buffer.message.header); continue;
        }
        @autoreleasepool {
          env event = buffer.message.descriptor.address;
          NSString *sender = @(env_get_value_for_key(event, "SENDER"));
          pid_t pid = (pid_t)strtol(env_get_value_for_key(event, "BAR_PID"), NULL, 10);
          if ([sender isEqual:@"--toggle"]) atomic_fetch_add(&requests, 1);
          if ([sender isEqual:@"--select"]) {
            [selectionLock lock]; pendingSelection = @(env_get_value_for_key(event, "ID")); [selectionLock unlock];
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            if ([sender isEqual:@"--toggle"]) {
              if ((atomic_exchange(&requests, 0) & 1) && execute(toggleScript)) sync_theme(NO);
            }
            else if ([sender isEqual:@"--select"]) select_theme();
            else if ([sender isEqual:@"--rebind"] && pid > 1) { barPID = pid; committed = nil; }
            else sync_theme([sender isEqual:@"--sync"]);
          });
          mach_msg_destroy(&buffer.message.header);
        }
      }
    });
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
      (void)timer; if (kill(barPID, 0) != 0) exit(0);
    }];
    fprintf(stderr, "Native theme ready for SketchyBar PID %d\n", barPID);
    [NSRunLoop.currentRunLoop run];
  }
  return 0;
}
