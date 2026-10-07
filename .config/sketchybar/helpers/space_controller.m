// GPL-3.0: SketchyBar IPC uses vendor/sketchybar.h.
// Desktop transactions run separately from the latency-sensitive hover daemon.
#import <Foundation/Foundation.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <pwd.h>
#include <fcntl.h>
#include <spawn.h>
#include <errno.h>
#include "vendor/sketchybar.h"

extern char **environ;
static NSString *root;
static NSString *rolesPath;
static NSString *const historyPath = @"/tmp/yabai_previous_semantic_space";
static BOOL barTransaction;
static NSNumber *lastFocusedID;

static void fail(NSString *message) {
  @throw [NSException exceptionWithName:@"SpaceController" reason:message userInfo:nil];
}

// No shell interpolation, jq processes, or queued keyboard jobs.
static NSData *run(NSString *program, NSArray<NSString *> *args) {
  int pipefd[2];
  if (pipe(pipefd)) fail(@"Cannot open command pipe");
  posix_spawn_file_actions_t actions;
  posix_spawn_file_actions_init(&actions);
  posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
  posix_spawn_file_actions_addclose(&actions, pipefd[0]);
  posix_spawn_file_actions_addclose(&actions, pipefd[1]);
  char **argv = calloc(args.count + 2, sizeof(char *));
  argv[0] = (char *)program.UTF8String;
  for (NSUInteger i = 0; i < args.count; i++) argv[i + 1] = (char *)args[i].UTF8String;
  pid_t pid;
  int error = posix_spawn(&pid, program.UTF8String, &actions, NULL, argv, environ);
  posix_spawn_file_actions_destroy(&actions);
  free(argv);
  close(pipefd[1]);
  if (error) { close(pipefd[0]); fail(@"Cannot launch desktop command"); }
  NSMutableData *output = [NSMutableData data];
  char buffer[8192];
  ssize_t length;
  while ((length = read(pipefd[0], buffer, sizeof(buffer))) != 0) {
    if (length < 0) { if (errno == EINTR) continue; break; }
    [output appendBytes:buffer length:(NSUInteger)length];
  }
  close(pipefd[0]);
  int status = 0;
  while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
  if (!WIFEXITED(status) || WEXITSTATUS(status)) fail(@"Desktop command failed");
  return output;
}

static NSData *yabai(NSArray<NSString *> *args) {
  // Same local client framing as official yabai 7.1.25 src/yabai.c. The daemon
  // still owns all native operations; no subprocess is needed per command.
  NSMutableData *body = [NSMutableData data];
  for (NSString *arg in args) {
    [body appendData:[arg dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendBytes:"" length:1];
  }
  [body appendBytes:"" length:1];
  int32_t length = (int32_t)body.length;
  NSMutableData *message = [NSMutableData dataWithBytes:&length length:sizeof(length)];
  [message appendData:body];
  int fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0) fail(@"Cannot open yabai client socket");
  fcntl(fd, F_SETFD, FD_CLOEXEC);
  int yes = 1;
  setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
  struct timeval timeout = {.tv_sec = 3};
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
  struct passwd *user = getpwuid(getuid());
  struct sockaddr_un address = {.sun_family = AF_UNIX};
  snprintf(address.sun_path, sizeof(address.sun_path), "/tmp/yabai_%s.socket", user ? user->pw_name : "");
  address.sun_len = sizeof(address);
  if (connect(fd, (struct sockaddr *)&address, sizeof(address))) {
    close(fd); fail(@"Cannot connect to yabai daemon");
  }
  NSUInteger sent = 0;
  while (sent < message.length) {
    ssize_t size = send(fd, (char *)message.bytes + sent, message.length - sent, 0);
    if (size < 0 && errno == EINTR) continue;
    if (size <= 0) { close(fd); fail(@"Cannot send yabai command"); }
    sent += size;
  }
  shutdown(fd, SHUT_WR);
  NSMutableData *response = [NSMutableData data];
  char buffer[8192];
  for (;;) {
    ssize_t size = read(fd, buffer, sizeof(buffer));
    if (size < 0 && errno == EINTR) continue;
    if (size < 0) { close(fd); fail(@"yabai response timed out"); }
    if (!size) break;
    [response appendBytes:buffer length:size];
    if (response.length > 4 * 1024 * 1024) { close(fd); fail(@"Oversized yabai response"); }
  }
  close(fd);
  if (response.length && ((const unsigned char *)response.bytes)[0] == 7) {
    NSData *reason = [response subdataWithRange:NSMakeRange(1, response.length - 1)];
    fail([[NSString alloc] initWithData:reason encoding:NSUTF8StringEncoding] ?: @"yabai command failed");
  }
  return response;
}

static id json(NSData *data) {
  id result = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL] : nil;
  if (!result) fail(@"Invalid desktop snapshot");
  return result;
}

static NSArray<NSMutableDictionary *> *spaces(void) {
  id result = json(yabai(@[@"query", @"--spaces"]));
  if (![result isKindOfClass:NSArray.class] || ![result count]) fail(@"No desktop snapshot");
  return result;
}

static NSArray *desktops(NSArray *all) {
  NSMutableArray *result = [NSMutableArray array];
  for (NSDictionary *space in all) if (![space[@"is-native-fullscreen"] boolValue]) [result addObject:space];
  return result;
}

static NSString *key(NSDictionary *space) {
  return [space[@"uuid"] length] ? space[@"uuid"] : [@"id:" stringByAppendingString:[space[@"id"] description]];
}

static NSDictionary *focused(NSArray *all) {
  for (NSDictionary *space in all) if ([space[@"has-focus"] boolValue]) return space;
  fail(@"No focused desktop");
  return nil;
}

static NSString *readText(NSString *path) {
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] ?: @"";
}

static void writeText(NSString *path, NSString *value) {
  NSError *error = nil;
  if (![value writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) fail(error.localizedDescription);
}

static void syncRoles(NSArray *all) {
  NSMutableDictionary *saved = [NSMutableDictionary dictionary];
  for (NSString *line in [readText(rolesPath) componentsSeparatedByString:@"\n"]) {
    NSArray *columns = [line componentsSeparatedByString:@"\t"];
    if (columns.count == 2) saved[columns[0]] = columns[1];
  }
  NSArray *ordered = [desktops(all) sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    NSString *ar = saved[key(a)] ?: a[@"label"];
    NSString *br = saved[key(b)] ?: b[@"label"];
    NSInteger ai = [ar hasPrefix:@"slot."] ? [[ar substringFromIndex:5] integerValue] : 100000 + [a[@"index"] integerValue];
    NSInteger bi = [br hasPrefix:@"slot."] ? [[br substringFromIndex:5] integerValue] : 100000 + [b[@"index"] integerValue];
    if (ai == bi) return [a[@"index"] compare:b[@"index"]];
    return ai < bi ? NSOrderedAscending : NSOrderedDescending;
  }];
  NSMutableString *state = [NSMutableString string];
  NSUInteger slot = 0;
  for (NSMutableDictionary *space in ordered) {
    NSString *role = [NSString stringWithFormat:@"slot.%lu", ++slot];
    if (![space[@"label"] isEqual:role]) {
      yabai(@[@"space", [space[@"index"] description], @"--label", role]);
      space[@"label"] = role;
    }
    [state appendFormat:@"%@\t%@\n", key(space), role];
  }
  if (![readText(rolesPath) isEqual:state]) writeText(rolesPath, state);
}

// Send exact NUL-separated argv through SketchyBar's supported Mach protocol.
// The whole message is frozen/redrawn by SketchyBar as a single transaction.
static BOOL bar(NSArray<NSString *> *args) {
  if (!g_mach_port) g_mach_port = mach_get_bs_port();
  if (!g_mach_port) return NO;
  NSMutableData *message = [NSMutableData data];
  for (NSString *arg in args) {
    NSData *bytes = [arg dataUsingEncoding:NSUTF8StringEncoding];
    [message appendData:bytes];
    [message appendBytes:"" length:1];
  }
  [message appendBytes:"" length:1];
  char *response = mach_send_message(g_mach_port, message.mutableBytes, (uint32_t)message.length);
  if (response && strstr(response, "[!]")) fail([NSString stringWithUTF8String:response]);
  return response != NULL;
}

static void beginBar(void) {
  barTransaction = bar(@[@"--trigger", @"native_topology_begin"]);
}

static void endBar(void) {
  if (barTransaction) bar(@[@"--trigger", @"native_topology_end", @"--trigger", @"space_change"]);
  barTransaction = NO;
}

static NSString *colorValue(const char *name, NSString *fallback) {
  const char *value = getenv(name);
  return value && *value ? [NSString stringWithUTF8String:value] : fallback;
}

static NSArray *renderPlan(NSArray *all, NSArray *windows) {
  NSMutableArray *plan = [NSMutableArray array];
  NSString *glyphCache = [NSString stringWithFormat:@"/tmp/sketchybar_app_glyphs_%u.json", getuid()];
  NSMutableArray *version = [NSMutableArray array];
  for (NSString *path in @[@"sketchybar/plugins/icon_map.sh", @"sketchybar/fonts/app_glyphs.sh"]) {
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:[root stringByAppendingPathComponent:path] error:NULL];
    [version addObject:@([attributes[NSFileModificationDate] timeIntervalSince1970])];
  }
  NSData *cached = [NSData dataWithContentsOfFile:glyphCache];
  NSDictionary *saved = cached ? [NSJSONSerialization JSONObjectWithData:cached options:0 error:NULL] : nil;
  NSMutableDictionary *glyphs = [saved[@"version"] isEqual:version] ? [saved[@"glyphs"] mutableCopy] : [NSMutableDictionary dictionary];
  BOOL changed = NO;
  for (NSDictionary *space in desktops(all)) {
    NSMutableSet *apps = [NSMutableSet set];
    NSInteger stack = 0;
    for (NSDictionary *window in windows) {
      if (![window[@"space"] isEqual:space[@"index"]]) continue;
      if ([window[@"app"] length]) [apps addObject:window[@"app"]];
      stack = MAX(stack, [window[@"stack-index"] integerValue]);
    }
    NSMutableArray *icons = [NSMutableArray array];
    for (NSString *app in [[apps allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
      if (!glyphs[app]) {
        NSData *data = run([root stringByAppendingPathComponent:@"sketchybar/plugins/icon_map.sh"], @[app]);
        glyphs[app] = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @":default:";
        changed = YES;
      }
      [icons addObject:glyphs[app]];
    }
    NSString *slot = [space[@"label"] hasPrefix:@"slot."] ? [space[@"label"] substringFromIndex:5] : [space[@"index"] description];
    NSString *number = stack > 1 ? [NSString stringWithFormat:@"%@·%ld", slot, (long)stack] : slot;
    NSInteger iconWidth = MAX(17, (NSInteger)number.length * 9 + 2);
    // Keep empty desktops recognizable without an empty app-icon slot.
    if (!icons.count) [icons addObject:@":desktop:"];
    NSInteger labelWidth = icons.count * 23;
    [plan addObject:@{@"id":space[@"id"], @"index":space[@"index"], @"slot":slot,
      @"display":space[@"display"], @"visible":space[@"is-visible"], @"number":number,
      @"label":[icons componentsJoinedByString:@"  "], @"labelWidth":@(labelWidth), @"iconWidth":@(iconWidth),
      @"width":@(iconWidth + labelWidth)}];
  }
  if (changed) [[NSJSONSerialization dataWithJSONObject:@{@"version":version, @"glyphs":glyphs} options:0 error:NULL] writeToFile:glyphCache atomically:YES];
  return plan;
}

static void render(NSArray *all, BOOL force) {
  if (!g_mach_port) g_mach_port = mach_get_bs_port();
  if (!g_mach_port) return; // Startup ordering: labels still work before the bar.
  NSDictionary *info = json([[NSString stringWithUTF8String:sketchybar("--query bar")] dataUsingEncoding:NSUTF8StringEncoding]);
  if (![info[@"items"] containsObject:@"apple_spacer"]) return;
  // yabai's focus event can lag its successful native focus acknowledgment.
  // Paint the known destination, not its briefly stale has-focus cache.
  NSDictionary *destination = nil;
  for (NSDictionary *space in all) if ([space[@"id"] isEqual:lastFocusedID]) destination = space;
  if (destination) for (NSMutableDictionary *space in all) {
    space[@"has-focus"] = @([space[@"id"] isEqual:lastFocusedID]);
    if ([space[@"display"] isEqual:destination[@"display"]]) space[@"is-visible"] = @([space[@"id"] isEqual:lastFocusedID]);
  }
  NSArray *plan = renderPlan(all, json(yabai(@[@"query", @"--windows"])));
  NSMutableSet *live = [NSMutableSet set];
  NSMutableSet *existing = [NSMutableSet set];
  for (NSDictionary *space in plan) {
    [live addObject:[@"space." stringByAppendingString:[space[@"id"] description]]];
    [live addObject:[@"space_spacer." stringByAppendingString:[space[@"id"] description]]];
  }
  for (NSString *name in info[@"items"]) if ([name hasPrefix:@"space."] || [name hasPrefix:@"space_spacer."]) [existing addObject:name];
  NSString *cache = [NSString stringWithFormat:@"/tmp/sketchybar_space_plan_%u.json", getuid()];
  NSData *saved = [NSData dataWithContentsOfFile:cache];
  id oldPlan = saved ? [NSJSONSerialization JSONObjectWithData:saved options:0 error:NULL] : nil;
  if (!force && [live isEqual:existing] && [plan isEqual:oldPlan]) return;
  if (!barTransaction) beginBar();
  NSMutableArray *args = [NSMutableArray array];
  for (NSString *name in existing) if (![live containsObject:name]) [args addObjectsFromArray:@[@"--remove", name]];
  NSString *previous = @"apple_spacer";
  for (NSDictionary *space in plan) {
    NSString *item = [@"space." stringByAppendingString:[space[@"id"] description]];
    NSString *spacer = [@"space_spacer." stringByAppendingString:[space[@"id"] description]];
    BOOL added = ![existing containsObject:item];
    if (added) [args addObjectsFromArray:@[@"--add", @"space", item, @"left"]];
    BOOL visible = [space[@"visible"] boolValue];
    NSString *fill = colorValue(visible ? "BLUE" : "ITEM_BG", visible ? @"0xff81a1c1" : @"0xb33b4252");
    NSString *outline = colorValue(visible ? "BLUE" : "ITEM_BORDER", visible ? @"0xff81a1c1" : @"0x5560728a");
    NSString *iconColor = colorValue(visible ? "ACTIVE_TEXT" : "TEXT", visible ? @"0xff2e3440" : @"0xffcdcecf");
    NSString *labelColor = colorValue(visible ? "ACTIVE_TEXT" : "SUBTEXT", visible ? @"0xff2e3440" : @"0xffd8dee9");
    [args addObjectsFromArray:@[@"--set", item,
      [@"space=" stringByAppendingString:[space[@"index"] description]],
      [@"icon=" stringByAppendingString:space[@"number"]],
      @"icon.font=JetBrainsMono Nerd Font Propo:Bold:14.0",
      [@"icon.width=" stringByAppendingString:[space[@"iconWidth"] description]], @"icon.align=right",
      @"icon.padding_left=0", @"icon.padding_right=2", @"icon.drawing=on",
      [@"label=" stringByAppendingString:space[@"label"]],
      @"label.font=Rice App Icons:Regular:14.0", @"label.max_chars=0", @"label.align=left",
      @"label.padding_left=2", @"label.padding_right=0", @"label.background.drawing=off",
      [@"label.drawing=" stringByAppendingString:([space[@"label"] length] ? @"on" : @"off")],
      [@"label.width=" stringByAppendingString:[space[@"labelWidth"] description]],
      @"padding_left=0", @"padding_right=0", @"background.height=28", @"background.corner_radius=10",
      @"background.drawing=on", @"background.border_width=1", @"background.shadow.drawing=off",
      [@"background.color=" stringByAppendingString:fill], [@"background.border_color=" stringByAppendingString:outline],
      [@"icon.color=" stringByAppendingString:iconColor], [@"label.color=" stringByAppendingString:labelColor],
      @"script=", @"mach_helper=com.denis.sketchybar.native_motion",
      [@"click_script=" stringByAppendingString:[NSString stringWithFormat:@"%@/yabai/scripts/focus_space.sh %@", root, space[@"slot"]]],
      @"--subscribe", item, @"mouse.entered", @"mouse.exited"]];
    // Only geometry animates, with all newly created pills entering together.
    // Numbers and app glyphs are committed immediately in the same message.
    if (added) [args addObjectsFromArray:@[@"--set", item, @"width=0"]];
    [args addObjectsFromArray:@[@"--animate", @"sin", @"5", @"--set", item,
      [@"width=" stringByAppendingString:[space[@"width"] description]], @"--animate", @"sin", @"0"]];
    if (![existing containsObject:spacer]) [args addObjectsFromArray:@[@"--add", @"item", spacer, @"left"]];
    [args addObjectsFromArray:@[@"--set", spacer, @"width=4", @"padding_left=0", @"padding_right=0",
      @"icon.drawing=off", @"label.drawing=off", @"background.drawing=off",
      @"--move", item, @"after", previous, @"--move", spacer, @"after", item]];
    previous = spacer;
  }
  if (bar(args)) [[NSJSONSerialization dataWithJSONObject:plan options:0 error:NULL] writeToFile:cache atomically:YES];
}

static NSArray *ensure(NSArray *all, NSUInteger target, NSString *source) {
  NSUInteger count = desktops(all).count;
  if (!count) fail(@"No ordinary desktops");
  if (count < target) {
    NSDictionary *current = focused(all);
    NSString *logPath = [NSString stringWithFormat:@"/tmp/yabai_space_creation_%u.log", getuid()];
    int fd = open(logPath.UTF8String, O_WRONLY|O_CREAT|O_APPEND, 0600);
    NSString *line = [NSString stringWithFormat:@"%@ pid=%d source=%@ target=%lu\n", [NSDate date], getpid(), source, target];
    if (fd >= 0) { write(fd, line.UTF8String, strlen(line.UTF8String)); close(fd); }
    beginBar();
    // Pin the originating monitor and create in one uninterrupted native burst.
    for (NSUInteger i = count; i < target; i++) yabai(@[@"space", @"--create", [current[@"display"] description]]);
    for (int attempt = 0; attempt < 100; attempt++) {
      all = spaces();
      if (desktops(all).count >= target) break;
      usleep(2000); // Only wait if Dock hasn't published the acknowledged burst.
    }
    if (desktops(all).count < target) fail(@"Dock did not publish the new desktops");
  }
  syncRoles(all);
  return all;
}

static NSDictionary *roleSpace(NSArray *all, NSUInteger slot) {
  NSString *role = [NSString stringWithFormat:@"slot.%lu", slot];
  for (NSDictionary *space in desktops(all)) if ([space[@"label"] isEqual:role]) return space;
  return nil;
}

static void focus(NSArray *all, NSDictionary *target, BOOL toggle) {
  NSDictionary *current = focused(all);
  if ([current[@"id"] isEqual:target[@"id"]]) {
    if (!toggle) return;
    NSString *oldKey = [readText(historyPath) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for (NSDictionary *space in all) if ([key(space) isEqual:oldKey] && ![key(space) isEqual:key(current)]) {
      yabai(@[@"space", @"--focus", [space[@"index"] description]]);
      lastFocusedID = space[@"id"];
      return;
    }
    yabai(@[@"space", @"--focus", @"recent"]);
    return;
  }
  writeText(historyPath, [key(current) stringByAppendingString:@"\n"]);
  yabai(@[@"space", @"--focus", [target[@"index"] description]]);
  lastFocusedID = target[@"id"];
}

int main(int argc, char **argv) {
  @autoreleasepool {
    const char *configOverride = getenv("DOTFILES_CONFIG_DIR");
    root = configOverride && *configOverride ? [NSString stringWithUTF8String:configOverride]
         : [NSHomeDirectory() stringByAppendingPathComponent:@".config"];
    rolesPath = [root stringByAppendingPathComponent:@"yabai/space_roles.tsv"];
    if (argc < 2) return 2;
    NSString *mode = [NSString stringWithUTF8String:argv[1]];
    // Read-only fixture mode for testing renumbering without touching desktops.
    if ([mode isEqual:@"--plan"]) {
      @try {
        NSDictionary *fixture = json([[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile]);
        NSData *output = [NSJSONSerialization dataWithJSONObject:renderPlan(fixture[@"spaces"], fixture[@"windows"]) options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(output.bytes, 1, output.length, stdout);
        return 0;
      } @catch (NSException *error) { return 1; }
    }
    NSUInteger slot = argc > 2 ? strtoul(argv[2], NULL, 10) : 0;
    BOOL createMissing = argc > 3 && !strcmp(argv[3], "--create-missing");
    if (([mode isEqual:@"--focus"] || [mode isEqual:@"--ensure"] || [mode isEqual:@"--move-window"]) &&
        (!slot || ((![mode isEqual:@"--focus"] || createMissing) && slot > 9) ||
         strspn(argv[2], "0123456789") != strlen(argv[2]))) return 2;
    if ([mode isEqual:@"--ensure"] && !createMissing) return 2;
    NSString *lockPath = [NSString stringWithFormat:@"/tmp/yabai_space_operation_%u.lock", getuid()];
    int lock = open(lockPath.UTF8String, O_CREAT|O_RDWR|O_CLOEXEC, 0600);
    if (lock < 0 || flock(lock, LOCK_EX|LOCK_NB)) { if (lock >= 0) close(lock); return 75; }
    int result = 0;
    @try {
      NSArray *all = spaces();
      if ([mode isEqual:@"--roles"]) syncRoles(all);
      else if ([mode isEqual:@"--refresh"]) {
        syncRoles(all); render(all, argc > 2 && !strcmp(argv[2], "--force"));
      } else if ([mode isEqual:@"--focus"] || [mode isEqual:@"--ensure"] || [mode isEqual:@"--move-window"]) {
        NSDictionary *target = roleSpace(all, slot);
        BOOL topologyChanged = target == nil;
        if (!target) {
          if (!createMissing && ![mode isEqual:@"--move-window"]) syncRoles(all);
          else all = ensure(all, slot, [mode isEqual:@"--move-window"] ? @"move-window-shortcut" : @"number-shortcut");
          target = roleSpace(all, slot);
        }
        if (!target) fail(@"Desktop does not exist; stale bar clicks never create one");
        if ([mode isEqual:@"--move-window"]) {
          NSDictionary *window = json(yabai(@[@"query", @"--windows", @"--window"]));
          yabai(@[@"window", [window[@"id"] description], @"--space", [target[@"index"] description]]);
        }
        if (![mode isEqual:@"--ensure"]) focus(all, target, [mode isEqual:@"--focus"]);
        if (topologyChanged || [mode isEqual:@"--move-window"]) render(spaces(), NO);
      } else if ([mode isEqual:@"--create"]) {
        NSUInteger count = desktops(all).count;
        all = ensure(all, count + 1, @"create-shortcut");
        focus(all, roleSpace(all, count + 1), NO);
        render(spaces(), NO);
      } else if ([mode isEqual:@"--destroy"]) {
        NSDictionary *current = focused(all), *destination = nil;
        if ([current[@"is-native-fullscreen"] boolValue]) fail(@"Cannot delete a native fullscreen desktop");
        for (NSDictionary *other in desktops(all)) {
          if (![other[@"display"] isEqual:current[@"display"]] || [other[@"id"] isEqual:current[@"id"]]) continue;
          if (!destination || ([other[@"index"] integerValue] < [current[@"index"] integerValue] &&
              [other[@"index"] integerValue] > [destination[@"index"] integerValue])) destination = other;
        }
        if (!destination) fail(@"Cannot delete the last desktop on a monitor");
        beginBar();
        focus(all, destination, NO);
        yabai(@[@"space", [current[@"index"] description], @"--destroy"]);
        all = spaces(); syncRoles(all); render(all, NO);
      } else fail(@"Unknown desktop operation");
    } @catch (NSException *error) {
      fprintf(stderr, "Space controller: %s\n", error.reason.UTF8String);
      // If Dock accepted part of a burst before an error, show only its real
      // published state. Recovery never retries or creates more desktops.
      if (barTransaction) @try {
        NSArray *actual = spaces(); syncRoles(actual); render(actual, YES);
      } @catch (NSException *recovery) {
        fprintf(stderr, "Space refresh: %s\n", recovery.reason.UTF8String);
      }
      result = 1;
    } @finally {
      endBar();
      if (lock >= 0) close(lock);
    }
    return result;
  }
}
