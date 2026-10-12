// GPL-3.0: uses FelixKratz/SketchyBarHelper (see vendor/LICENSE).
// Native pointer/Space events never launch a shell or query yabai.
#import <Foundation/Foundation.h>
#include <signal.h>
#include <spawn.h>
#include <stdbool.h>
#include <string.h>
#include "native_ipc.h"
#include "space_layout.h"

extern char **environ;
static char port_name[] = "com.denis.sketchybar.native_motion";
static NSString *config_directory;
static const char *config_dir;
static pid_t bar_pid;
static char hovered[128];
static double hover_leave_deadline;
static NSMutableSet<NSString *> *selected;
static NSMutableDictionary<NSString *, NSDictionary *> *spacePlans;
static NSString *expanded;
static bool topology_busy;
static double topology_started;
static uint32_t bg, strong, border, blue, text, active_text, subtext;
static uint32_t green, yellow, red;

static uint32_t color(const char *value, uint32_t fallback) {
  return value && *value ? (uint32_t)strtoul(value, NULL, 16) : fallback;
}

static void palette(env event) {
#define LOAD(field, key, fallback) field = color(event ? env_get_value_for_key(event, key) : getenv(key), fallback)
  LOAD(bg, "ITEM_BG", 0xb33b4252);
  LOAD(strong, "ITEM_BG_STRONG", 0xe63e4a5b);
  LOAD(border, "ITEM_BORDER", 0x5560728a);
  LOAD(blue, "BLUE", 0xff81a1c1);
  LOAD(text, "TEXT", 0xffcdcecf);
  LOAD(active_text, "ACTIVE_TEXT", 0xff2e3440);
  LOAD(subtext, "SUBTEXT", 0xffd8dee9);
  LOAD(green, "GREEN", 0xffa3be8c);
  LOAD(yellow, "YELLOW", 0xffebcb8b);
  LOAD(red, "RED", 0xffbf616a);
#undef LOAD
}

static bool space_item(const char *name) {
  if (strncmp(name, "space.", 6)) return false;
  char *end;
  unsigned long long value = strtoull(name + 6, &end, 10);
  return !*end && value > 0;
}

static NSString *space_owner(const char *name) {
  if (space_item(name)) return @(name);
  NSString *item = @(name);
  if ([item hasPrefix:@"space_app."] || [item hasPrefix:@"space_more."]) {
    NSArray *parts = [item componentsSeparatedByString:@"."];
    if (parts.count >= 2) return [@"space." stringByAppendingString:parts[1]];
  }
  return nil;
}

static bool interactive(const char *name) {
  if (space_owner(name) || !strncmp(name, "cc.", 3)) return true;
  const char *items[] = {"apple", "front_app", "media", "cpu", "memory",
                        "network", "volume", "battery", "clock", NULL};
  for (int i = 0; items[i]; ++i) if (!strcmp(name, items[i])) return true;
  return false;
}

static bool strong_item(const char *name) {
  return !strcmp(name, "apple") || !strcmp(name, "front_app")
      || !strcmp(name, "clock") || !strcmp(name, "media")
      || !strcmp(name, "cc.header") || !strcmp(name, "cc.settings")
      || !strcmp(name, "cc.appearance") || !strcmp(name, "cc.sleep");
}

static uint32_t base_color(const char *name) {
  NSString *owner = space_owner(name);
  if (owner && [selected containsObject:owner]) return blue;
  return strong_item(name) ? strong : bg;
}

static uint32_t highlight(uint32_t base) {
  // A gentle highlight without changing size, text baseline or hit target.
  unsigned luminance = ((base >> 16) & 255) * 299
                     + ((base >> 8) & 255) * 587 + (base & 255) * 114;
  uint32_t result = base & 0xff000000;
  for (int shift = 0; shift <= 16; shift += 8) {
    unsigned channel = (base >> shift) & 255;
    if (luminance > 160000) {
      // White-on-white was invisible in the light palette. Tint toward its
      // blue accent instead; leave the existing dark hover unchanged.
      unsigned accent = (blue >> shift) & 255;
      channel = (channel * 86 + accent * 14) / 100;
    } else {
      channel += (255 - channel) / 10;
    }
    result |= channel << shift;
  }
  return result;
}

static void fill_command(char *command, size_t size, const char *name, bool enter) {
  uint32_t fill = base_color(name);
  if (enter) fill = highlight(fill);
  NSString *owner = space_owner(name);
  if (owner) {
    snprintf(command, size, "--set %s background.color=0x%08x", rice_space_group_name(owner).UTF8String, fill);
    return;
  }
  int outline = !strncmp(name, "cc.", 3) || !strncmp(name, "space_", 6) ? 0 : 1;
  snprintf(command, size,
           "--set %s background.color=0x%08x "
           "icon.y_offset=0 label.y_offset=0 background.border_width=%d "
           "background.shadow.drawing=off",
           name, fill, outline);
}

static NSString *hex(uint32_t value) { return [NSString stringWithFormat:@"0x%08x", value]; }

static void append_group(NSMutableArray *args, NSString *owner, BOOL open) {
  NSDictionary *plan = owner ? spacePlans[owner] : nil;
  if (!plan || [plan[@"appCount"] integerValue] <= 1) return;
  NSString *sid = [owner substringFromIndex:6];
  BOOL active = [selected containsObject:owner];
  uint32_t tint = active ? active_text : text;
  // The first app is the owner's label, not a child item. Its slot must track
  // the same pitch as every child, in both directions of the hover animation.
  rice_space_primary_layout(args, owner, plan, open);
  for (NSUInteger i = 1; i < [plan[@"apps"] count]; i++) {
    NSString *child = [NSString stringWithFormat:@"space_app.%@.%lu", sid, i];
    BOOL visible = rice_space_child_visible(i, open);
    rice_space_child_layout(args, child, i, open);
    [args addObjectsFromArray:@[@"--set", child,
      [@"icon.color=" stringByAppendingString:hex(visible ? tint : 0)]]];
  }
  NSString *badgeName = [@"space_more." stringByAppendingString:sid];
  BOOL badge = rice_space_overflow([plan[@"appCount"] integerValue], open) > 0;
  rice_space_badge_layout(args, badgeName, [plan[@"appCount"] integerValue], open);
  [args addObjectsFromArray:@[@"--set", badgeName,
    [@"label.color=" stringByAppendingString:hex(badge ? (active ? active_text : subtext) : 0)]]];
}

static void expand_space(NSString *owner) {
  if ([owner isEqual:expanded]) return;
  NSMutableArray *args = [NSMutableArray arrayWithArray:@[@"--animate", @"sin", @"7"]];
  if (expanded) append_group(args, expanded, NO);
  expanded = owner && [spacePlans[owner][@"appCount"] integerValue] > 1 ? owner : nil;
  if (expanded) append_group(args, expanded, YES);
  if (args.count > 3) rice_bar(args);
}

static void hover(const char *name, const char *sender) {
  char command[1400], previous[550] = "", next[550] = "";
  if (!strcmp(sender, "mouse.entered")) {
    if (!interactive(name)) return;
    hover_leave_deadline = 0;
    if (!strcmp(name, hovered)) return;
    char old[sizeof(hovered)];
    snprintf(old, sizeof(old), "%s", hovered);
    snprintf(hovered, sizeof(hovered), "%s", name);
    expand_space(space_owner(name));
    if (*old && ![space_owner(old) isEqual:space_owner(name)]) fill_command(previous, sizeof(previous), old, false);
    fill_command(next, sizeof(next), name, true);
  } else {
    BOOL global = !strcmp(sender, "mouse.exited.global");
    if (global) hover_leave_deadline = 0;
    // An old exit event must never cancel the newer hovered item.
    if (!*hovered) {
      if (global) expand_space(nil);
      return;
    }
    if (!global && strcmp(name, hovered)) return;
    // Sibling logo windows report separate exits/entries. Give the next entry
    // 30 ms to arrive; a genuine pill exit still collapses without a global exit.
    if (!global && space_owner(hovered)) {
      hover_leave_deadline = NSProcessInfo.processInfo.systemUptime + 0.030;
      return;
    }
    expand_space(nil);
    fill_command(previous, sizeof(previous), hovered, false);
    *hovered = '\0';
  }
  // The helper protocol treats spaces as token separators. An empty previous
  // item must not introduce an empty token before the first --set command.
  snprintf(command, sizeof(command), "--animate sin 5 %s%s%s", previous,
           *previous && *next ? " " : "", next);
  sketchybar(command);
}

static void apply_theme(env event) {
  palette(event);
#define C(key) @(env_get_value_for_key(event, key))
  NSMutableArray *args = [NSMutableArray arrayWithArray:@[@"--animate", @"sin", @"8",
    @"--bar", [@"color=" stringByAppendingString:C("BAR_COLOR")], [@"border_color=" stringByAppendingString:C("BAR_BORDER")],
    @"--default", [@"icon.color=" stringByAppendingString:hex(text)], [@"label.color=" stringByAppendingString:hex(text)],
    [@"background.color=" stringByAppendingString:hex(bg)], [@"background.border_color=" stringByAppendingString:hex(border)]]];
  for (NSString *name in @[@"apple", @"front_app", @"media", @"cpu", @"memory", @"network", @"volume", @"battery", @"clock"]) {
    uint32_t fill = strong_item(name.UTF8String) ? strong : bg;
    if (!strcmp(name.UTF8String, hovered)) fill = highlight(fill);
    [args addObjectsFromArray:@[@"--set", name, [@"background.color=" stringByAppendingString:hex(fill)],
      [@"background.border_color=" stringByAppendingString:hex(border)],
      [@"icon.color=" stringByAppendingString:hex(text)], [@"label.color=" stringByAppendingString:hex(text)]]];
  }
  NSDictionary *accents = @{@"apple":C("MAUVE"), @"media":C("MAUVE"), @"clock":C("MAUVE"),
    @"cpu":C("GREEN"), @"memory":C("YELLOW"), @"network":C("TEAL"), @"volume":C("BLUE"), @"battery":C("GREEN")};
  for (NSString *name in accents) [args addObjectsFromArray:@[@"--set", name, [@"icon.color=" stringByAppendingString:accents[name]]]];
  for (NSString *name in @[@"front_app"])
    [args addObjectsFromArray:@[@"--set", name, [@"label.color=" stringByAppendingString:hex(subtext)]]];
  [args addObjectsFromArray:@[@"--set", @"media", [@"background.border_color=" stringByAppendingString:C("MAUVE")],
    @"--set", @"cpu", [@"graph.color=" stringByAppendingString:C("GREEN")], [@"graph.fill_color=" stringByAppendingString:C("GREEN_FILL")]]];
  for (NSString *owner in spacePlans) {
    BOOL active = [selected containsObject:owner];
    uint32_t fill = active ? blue : bg;
    if ([space_owner(hovered) isEqual:owner]) fill = highlight(fill);
    [args addObjectsFromArray:@[@"--set", rice_space_group_name(owner),
      [@"background.color=" stringByAppendingString:hex(fill)],
      [@"background.border_color=" stringByAppendingString:hex(active ? blue : border)],
      @"--set", owner,
      [@"icon.color=" stringByAppendingString:hex(active ? active_text : text)],
      [@"label.color=" stringByAppendingString:hex(active ? active_text : subtext)]]];
    append_group(args, owner, [owner isEqual:expanded]);
  }
  rice_bar(args);
#undef C
}

static void select_space(const char *name, env event) {
  if (!space_item(name) || topology_busy) return;
  NSString *item = [NSString stringWithUTF8String:name];
  const char *value = env_get_value_for_key(event, "SELECTED");
  bool active = !strcmp(value, "true");
  bool previous = [selected containsObject:item];
  if (active) [selected addObject:item];
  else [selected removeObject:item];
  // A topology batch already painted all pills. Forced unchanged selection
  // events must not restart their colour animations or flood the bar with IPC.
  if (active == previous) return;
  uint32_t fill = base_color(name);
  if ([space_owner(hovered) isEqual:item]) fill = highlight(fill);
  NSMutableArray *args = [NSMutableArray arrayWithArray:@[@"--animate", @"sin", @"5",
    @"--set", rice_space_group_name(item), [@"background.color=" stringByAppendingString:hex(fill)],
    [@"background.border_color=" stringByAppendingString:hex(active ? blue : border)],
    @"--set", item, [@"icon.color=" stringByAppendingString:hex(active ? active_text : text)],
    [@"label.color=" stringByAppendingString:hex(active ? active_text : subtext)]]];
  append_group(args, item, [item isEqual:expanded]);
  rice_bar(args);
}

static const char *plugin_for(const char *name) {
  const char *names[] = {"front_app", "media", "cpu", "memory", "network",
                        "volume", "battery", "clock", NULL};
  for (int i = 0; names[i]; ++i) if (!strcmp(name, names[i])) return names[i];
  return NULL;
}

static void update_widget(const char *name, env event) {
  const char *plugin = plugin_for(name);
  if (!plugin) return;
  // Only actual data events spawn a plugin. Preserve the exact event env,
  // including multiline INFO, without sending it through shell quoting.
  NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];
  for (char **entry = environ; *entry; ++entry) {
    const char *equals = strchr(*entry, '=');
    if (!equals) continue;
    NSString *key = [[NSString alloc] initWithBytes:*entry length:equals - *entry encoding:NSUTF8StringEncoding];
    NSString *value = [NSString stringWithUTF8String:equals + 1];
    if (key && value) values[key] = value;
  }
  for (char *key = event; *key;) {
    char *value = key + strlen(key) + 1;
    NSString *k = [NSString stringWithUTF8String:key];
    NSString *v = [NSString stringWithUTF8String:value];
    if (k && v) values[k] = v;
    key = value + strlen(value) + 1;
  }
  values[@"CONFIG_DIR"] = @(config_dir);
  // Plugin colors.sh reads the live committed theme, not the helper's
  // launch-time environment, which could otherwise restore the old palette.
  [values removeObjectForKey:@"THEME_MODE"];
  char **environment = calloc(values.count + 1, sizeof(char *));
  size_t index = 0;
  for (NSString *key in values) {
    environment[index++] = strdup([[NSString stringWithFormat:@"%@=%@", key, values[key]] UTF8String]);
  }
  char path[512];
  snprintf(path, sizeof(path), "%s/plugins/%s.sh", config_dir, plugin);
  char *args[] = {"/bin/sh", path, NULL};
  pid_t child;
  int result = posix_spawn(&child, "/bin/sh", NULL, NULL, args, environment);
  if (result) fprintf(stderr, "Could not spawn %s: %s\n", plugin, strerror(result));
  for (size_t i = 0; i < index; ++i) free(environment[i]);
  free(environment);
}

static void update_cpu(void) {
  // Kernel CPU ticks avoid scanning every process for every graph sample.
  static mach_port_t host;
  static host_cpu_load_info_data_t previous;
  host_cpu_load_info_data_t current;
  mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
  if (!host) host = mach_host_self();
  if (host_statistics(host, HOST_CPU_LOAD_INFO,
                      (host_info_t)&current, &count) != KERN_SUCCESS) return;
  uint64_t total = 0, idle = 0;
  for (int i = 0; i < CPU_STATE_MAX; ++i) {
    uint32_t ticks = current.cpu_ticks[i] - previous.cpu_ticks[i];
    total += ticks;
    if (i == CPU_STATE_IDLE) idle = ticks;
  }
  previous = current;
  if (!total) return;
  double usage = (double)(total - idle) / total;
  unsigned percent = (unsigned)(usage * 100.0 + 0.5);
  uint32_t tint = percent >= 80 ? red : percent >= 55 ? yellow : green;
  char command[256];
  snprintf(command, sizeof(command),
           "--push cpu %.4f --set cpu label=%u%% icon.color=0x%08x graph.color=0x%08x",
           usage, percent, tint, tint);
  sketchybar(command);
}

MACH_HANDLER(on_event) {
  @autoreleasepool {
    const char *sender = env_get_value_for_key(env, "SENDER");
    const char *name = env_get_value_for_key(env, "NAME");
    if (!strcmp(sender, "mouse.clicked") && !strcmp(name, "apple")) {
      rice_post("com.denis.sketchybar.native_panel", @{@"SENDER":@"--toggle"}); return;
    }
    if (!strcmp(sender, "native_theme_palette")) { apply_theme(env); return; }
    if (!strcmp(sender, "native_space_plan")) {
      NSData *data = [@(env_get_value_for_key(env, "INFO")) dataUsingEncoding:NSUTF8StringEncoding];
      NSArray *plan = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
      if (![plan isKindOfClass:NSArray.class]) return;
      [spacePlans removeAllObjects];
      [selected removeAllObjects];
      expanded = nil;
      for (NSDictionary *row in plan) {
        NSString *owner = [@"space." stringByAppendingString:[row[@"id"] description]];
        spacePlans[owner] = row;
        if ([row[@"visible"] boolValue]) [selected addObject:owner];
      }
      return;
    }
    if (!strcmp(name, "hover_observer") && !strcmp(sender, "space_change")) {
      hover("", "mouse.exited.global");
      return;
    }
    if (!strcmp(sender, "native_rebind")) {
      pid_t pid = (pid_t)strtol(env_get_value_for_key(env, "BAR_PID"), NULL, 10);
      if (pid > 1 && pid != bar_pid) {
        // A service restart replaces SketchyBar's server port. Do not keep
        // sending to the old daemon if startup reuses this live helper.
        if (g_mach_port) mach_port_deallocate(mach_task_self(), g_mach_port);
        g_mach_port = MACH_PORT_NULL;
        *hovered = '\0';
        hover_leave_deadline = 0;
        [selected removeAllObjects];
        [spacePlans removeAllObjects];
        expanded = nil;
        topology_busy = false;
        bar_pid = pid;
      }
      return;
    }
    if (!strcmp(sender, "native_topology_begin")) {
      hover("", "mouse.exited.global");
      topology_busy = true;
      topology_started = [NSDate timeIntervalSinceReferenceDate];
      return;
    }
    if (!strcmp(sender, "native_topology_end")) {
      topology_busy = false;
      [selected removeAllObjects];
      return;
    }
    if (!strcmp(sender, "native_palette_changed")) {
      palette(env);
      hover_leave_deadline = 0;
      if (*hovered) {
        char command[600], item[128];
        snprintf(item, sizeof(item), "%s", hovered);
        fill_command(command, sizeof(command), item, false);
        sketchybar(command);
        *hovered = '\0';
      }
      return;
    }
    bool trace = false;
    if (!strcmp(sender, "native_hover_test")) {
      trace = !strcmp(env_get_value_for_key(env, "DEBUG"), "1");
      name = env_get_value_for_key(env, "ITEM");
      sender = env_get_value_for_key(env, "EVENT");
    }
    if (!strncmp(sender, "mouse.", 6)) {
      hover(name, sender);
      if (trace) fprintf(stderr, "Hover probe: %s %s; current=%s\n", name, sender, hovered);
      return;
    }
    if (!strcmp(name, "cpu")) update_cpu();
    else if (space_item(name)) select_space(name, env);
    else update_widget(name, env);
  }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static mach_port_t lookup(void) {
  mach_port_t port = MACH_PORT_NULL;
  bootstrap_look_up(bootstrap_port, port_name, &port);
  return port;
}

static bool register_port(void) {
  mach_port_t port;
  if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS) return false;
  mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
  struct mach_port_limits limits = {.mpl_qlimit = MACH_PORT_QLIMIT_LARGE};
  mach_port_set_attributes(mach_task_self(), port, MACH_PORT_LIMITS_INFO, (mach_port_info_t)&limits, MACH_PORT_LIMITS_INFO_COUNT);
  kern_return_t result = bootstrap_register(bootstrap_port, port_name, port);
  if (result != KERN_SUCCESS) {
    fprintf(stderr, "Native motion port registration failed: %s\n", mach_error_string(result));
    return false;
  }
  g_mach_server.port = port;
  return true;
}
#pragma clang diagnostic pop

static void receive_event(struct mach_buffer *buffer) {
  // Sleep in Mach until an event or the pending leave deadline, not a polling
  // timer. Normal operation retains the one-second daemon lifecycle check.
  mach_msg_timeout_t timeout = 1000;
  if (hover_leave_deadline) {
    double remaining = (hover_leave_deadline - NSProcessInfo.processInfo.systemUptime) * 1000;
    timeout = (mach_msg_timeout_t)MAX(1, MIN(1000, (int)(remaining + 1)));
  }
  *buffer = (struct mach_buffer){0};
  mach_msg_return_t result = mach_msg(&buffer->message.header,
    MACH_RCV_MSG | MACH_RCV_TIMEOUT, 0, sizeof(*buffer),
    g_mach_server.port, timeout, MACH_PORT_NULL);
  if (result != MACH_MSG_SUCCESS) buffer->message.descriptor.address = NULL;
}

int main(int argc, char **argv) {
  const char *config = getenv("CONFIG_DIR");
  config_directory = config && *config ? [NSString stringWithUTF8String:config]
                   : [NSHomeDirectory() stringByAppendingPathComponent:@".config/sketchybar"];
  config_dir = config_directory.UTF8String;
  selected = [NSMutableSet set];
  spacePlans = [NSMutableDictionary dictionary];
  if (argc == 2 && !strcmp(argv[1], "--plan-expansion")) {
    @autoreleasepool {
      NSDictionary *fixture = [NSJSONSerialization JSONObjectWithData:
        [NSFileHandle.fileHandleWithStandardInput readDataToEndOfFile] options:0 error:NULL];
      NSDictionary *row = fixture[@"space"];
      if (![row[@"id"] isKindOfClass:NSNumber.class] || ![row[@"apps"] isKindOfClass:NSArray.class]) return 2;
      NSString *owner = [@"space." stringByAppendingString:[row[@"id"] description]];
      spacePlans[owner] = row;
      if ([row[@"visible"] boolValue]) [selected addObject:owner];
      palette(NULL);
      NSMutableArray *args = [NSMutableArray array];
      append_group(args, owner, [fixture[@"open"] boolValue]);
      NSData *data = [NSJSONSerialization dataWithJSONObject:args options:0 error:NULL];
      fwrite(data.bytes, 1, data.length, stdout); return 0;
    }
  }
  if (argc > 1 && !strcmp(argv[1], "--ready")) return lookup() ? 0 : 1;
  if (argc < 3 || strcmp(argv[1], "--ensure")) return 2;
  bar_pid = (pid_t)strtol(argv[2], NULL, 10);
  if (bar_pid <= 1) return 2;
  // A bar reload keeps the same helper. A service restart gets a new port.
  mach_port_t existing = lookup();
  if (existing) {
    char message[128];
    int length = snprintf(message, sizeof(message), "SENDER%cnative_rebind%cBAR_PID%c%d%c",
                          0, 0, 0, bar_pid, 0) + 1;
    struct mach_message event = {0};
    event.header.msgh_remote_port = existing;
    event.header.msgh_bits = MACH_MSGH_BITS_SET(MACH_MSG_TYPE_COPY_SEND, 0, 0, MACH_MSGH_BITS_COMPLEX);
    event.header.msgh_size = sizeof(event);
    event.msgh_descriptor_count = 1;
    event.descriptor.address = message;
    event.descriptor.size = length;
    event.descriptor.copy = MACH_MSG_VIRTUAL_COPY;
    event.descriptor.type = MACH_MSG_OOL_DESCRIPTOR;
    mach_msg_return_t result = mach_msg(&event.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT,
                                       sizeof(event), 0, MACH_PORT_NULL, 100, MACH_PORT_NULL);
    mach_port_deallocate(mach_task_self(), existing);
    if (result == MACH_MSG_SUCCESS) return 0;
  }
  pid_t child = fork();
  if (child < 0) return 1;
  if (child) {
    for (int i = 0; i < 200; ++i) {
      mach_port_t port = lookup();
      if (port) {
        mach_port_deallocate(mach_task_self(), port);
        return 0;
      }
      usleep(10000);
    }
    return 1;
  }
  setsid();
  signal(SIGCHLD, SIG_IGN);
  freopen("/dev/null", "r", stdin);
  char log_path[256];
  snprintf(log_path, sizeof(log_path), "/tmp/sketchybar_native_motion_%u.log", getuid());
  freopen(log_path, "a", stderr);
  setvbuf(stderr, NULL, _IONBF, 0);
  freopen("/dev/null", "w", stdout);
  palette(NULL);
  if (!register_port()) return 1;
  fprintf(stderr, "Native motion ready for SketchyBar PID %d\n", bar_pid);
  for (;;) {
    struct mach_buffer buffer;
    receive_event(&buffer);
    if (buffer.message.descriptor.address) {
      // SketchyBar sends a two-byte "k" control packet during reload/exit.
      // Reuse this helper on reload, but never parse that packet as an env.
      if (buffer.message.descriptor.size == 2 &&
          *(char *)buffer.message.descriptor.address == 'k') {
        *hovered = '\0';
        hover_leave_deadline = 0;
      } else {
        on_event((env)buffer.message.descriptor.address);
      }
      mach_msg_destroy(&buffer.message.header);
    }
    if (hover_leave_deadline && NSProcessInfo.processInfo.systemUptime >= hover_leave_deadline)
      hover("", "mouse.exited.global");
    if (kill(bar_pid, 0) != 0) break;
    // A killed controller must not leave selection updates paused forever.
    if (topology_busy && [NSDate timeIntervalSinceReferenceDate] - topology_started > 2.0) {
      topology_busy = false;
      [selected removeAllObjects];
      sketchybar("--trigger yabai_space_snapshot --trigger space_change");
    }
  }
  return 0;
}
