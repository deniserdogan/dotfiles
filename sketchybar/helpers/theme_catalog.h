// GPL-3.0. One validated catalog drives the native coordinator and gallery.
#pragma once
#import <Foundation/Foundation.h>

static inline id rice_json_file(NSString *path) {
  NSData *data = [NSData dataWithContentsOfFile:path];
  return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
}

static inline BOOL rice_matches(NSString *value, NSString *pattern) {
  return [value isKindOfClass:NSString.class] &&
    [value rangeOfString:pattern options:NSRegularExpressionSearch].location != NSNotFound;
}

static inline NSArray<NSDictionary *> *rice_themes(NSString *directory) {
  id rows = rice_json_file([directory stringByAppendingPathComponent:@"themes/catalog.json"]);
  if (![rows isKindOfClass:NSArray.class] || ![rows count]) return nil;
  NSMutableSet *ids = [NSMutableSet set];
  for (NSDictionary *row in rows) {
    if (![row isKindOfClass:NSDictionary.class] || !rice_matches(row[@"id"], @"^[a-z0-9-]+$") ||
        [ids containsObject:row[@"id"]] || ![@[@"dark", @"light"] containsObject:row[@"mode"]] ||
        !rice_matches(row[@"neovim"], @"^[a-z0-9_-]+$") ||
        !rice_matches(row[@"ghostty"], @"^[A-Za-z0-9 -]+$") ||
        ![row[@"name"] isKindOfClass:NSString.class] || ![row[@"description"] isKindOfClass:NSString.class] ||
        ![row[@"colors"] isKindOfClass:NSDictionary.class] ||
        (row[@"overrides"] && ![row[@"overrides"] isKindOfClass:NSDictionary.class])) return nil;
    [ids addObject:row[@"id"]];
    for (NSString *key in @[@"background", @"surface", @"foreground", @"blue", @"teal", @"green", @"yellow", @"peach", @"red", @"mauve"])
      if (!rice_matches(row[@"colors"][key], @"^[0-9a-fA-F]{6}$")) return nil;
    for (NSString *key in row[@"overrides"])
      if (!rice_matches(key, @"^[A-Z_]+$") || !rice_matches(row[@"overrides"][key], @"^0x[0-9a-fA-F]{8}$")) return nil;
  }
  if (![ids containsObject:@"nordfox"] || ![ids containsObject:@"xcode-light"]) return nil;
  // Keep authored order within each appearance, even when new themes are
  // appended to the catalog. The All gallery always has one dark/light boundary.
  NSMutableArray *grouped = [NSMutableArray arrayWithCapacity:[rows count]];
  for (NSString *mode in @[@"dark", @"light"])
    for (NSDictionary *row in rows) if ([row[@"mode"] isEqual:mode]) [grouped addObject:row];
  return grouped;
}

static inline NSDictionary *rice_theme(NSArray *catalog, NSString *identifier) {
  for (NSDictionary *row in catalog) if ([row[@"id"] isEqual:identifier]) return row;
  return nil;
}

static inline NSString *rice_argb(NSString *rgb, unsigned alpha) {
  return [NSString stringWithFormat:@"0x%02x%@", alpha, rgb];
}

static inline NSString *rice_mix(NSString *a, NSString *b, double amount) {
  unsigned first = (unsigned)strtoul(a.UTF8String, NULL, 16), second = (unsigned)strtoul(b.UTF8String, NULL, 16), mixed = 0;
  for (int shift = 0; shift <= 16; shift += 8)
    mixed |= (unsigned)(((first >> shift) & 255) * (1-amount) + ((second >> shift) & 255) * amount) << shift;
  return [NSString stringWithFormat:@"%06x", mixed];
}

static inline NSDictionary *rice_theme_palette(NSDictionary *theme) {
  if (!theme) return nil;
  NSDictionary *c = theme[@"colors"];
  NSMutableDictionary *palette = [@{
    @"BAR_COLOR":rice_argb(c[@"background"], 0xe6), @"BAR_BORDER":rice_argb(c[@"foreground"], 0x66),
    @"ITEM_BG":rice_argb(c[@"surface"], 0xb3),
    @"ITEM_BG_STRONG":rice_argb(rice_mix(c[@"surface"], c[@"blue"], .12), 0xe6),
    @"ITEM_BORDER":rice_argb(c[@"foreground"], 0x55), @"TEXT":rice_argb(c[@"foreground"], 0xff),
    @"ACTIVE_TEXT":rice_argb([theme[@"mode"] isEqual:@"dark"] ? c[@"background"] : @"ffffff", 0xff),
    @"SUBTEXT":rice_argb(rice_mix(c[@"foreground"], c[@"background"], .22), 0xff),
    @"MUTED":rice_argb(rice_mix(c[@"foreground"], c[@"background"], .48), 0xff),
    @"GREEN_FILL":rice_argb(c[@"green"], 0x25)
  } mutableCopy];
  for (NSString *key in @[@"blue", @"teal", @"green", @"yellow", @"peach", @"red", @"mauve"])
    palette[key.uppercaseString] = rice_argb(c[key], 0xff);
  [palette addEntriesFromDictionary:theme[@"overrides"] ?: @{}];
  return palette;
}

// One native style for startup and live appearance commits. Keep the gradient
// close to the theme's primary accent, with no glow or terminal background fill.
static inline NSArray<NSString *> *rice_border_arguments(NSDictionary *theme, BOOL includeGeometry) {
  if (!theme) return nil;
  NSDictionary *palette = rice_theme_palette(theme);
  NSString *blue = [palette[@"BLUE"] substringFromIndex:4];
  NSString *mauve = [palette[@"MAUVE"] substringFromIndex:4];
  NSString *foreground = [palette[@"TEXT"] substringFromIndex:4];
  NSString *gradient = [NSString stringWithFormat:@"active_color=gradient(top_left=%@,bottom_right=%@)",
    rice_argb(blue, 0xff), rice_argb(rice_mix(blue, mauve, .40), 0xee)];
  NSString *inactive = [@"inactive_color=" stringByAppendingString:
    rice_argb(foreground, [theme[@"mode"] isEqual:@"dark"] ? 0x24 : 0x1c)];
  NSArray *colors = @[gradient, inactive];
  // Even an unchanged hidpi option makes JankyBorders recreate all overlays.
  // Appearance commits send only colours, leaving native window geometry alone.
  return includeGeometry ? [@[@"style=round", @"width=2.0", @"hidpi=on", @"background_color=0x00000000"]
    arrayByAddingObjectsFromArray:colors] : colors;
}

static inline NSString *rice_selection_path(NSString *directory) {
  // Persistent choices must live outside SketchyBar's hotload-watched tree.
  return [[directory stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"rice/theme-selection.json"];
}

static inline NSMutableDictionary *rice_theme_selection(NSString *directory, NSArray *catalog) {
  id saved = rice_json_file(rice_selection_path(directory));
  if (!saved) saved = rice_json_file([directory stringByAppendingPathComponent:@"themes/selection.json"]);
  NSMutableDictionary *selection = [@{@"dark":@"nordfox", @"light":@"xcode-light"} mutableCopy];
  for (NSString *mode in @[@"dark", @"light"])
    if ([saved isKindOfClass:NSDictionary.class] && [rice_theme(catalog, saved[mode])[@"mode"] isEqual:mode]) selection[mode] = saved[mode];
  return selection;
}

static inline BOOL rice_remember_theme(NSString *directory, NSArray *catalog,
    NSMutableDictionary *selection, NSString *identifier) {
  NSDictionary *theme = rice_theme(catalog, identifier);
  if (!theme) return NO;
  NSMutableDictionary *next = [selection mutableCopy];
  next[theme[@"mode"]] = identifier;
  NSData *data = [NSJSONSerialization dataWithJSONObject:next options:NSJSONWritingSortedKeys error:NULL];
  NSString *path = rice_selection_path(directory);
  if (!data || ![NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES attributes:nil error:NULL]) return NO;
  if (![[NSData dataWithContentsOfFile:path] isEqual:data] && ![data writeToFile:path atomically:YES]) return NO;
  // Failed writes must not leave an in-memory choice that disappears on restart.
  [selection setDictionary:next];
  return YES;
}

static inline NSString *rice_theme_state_path(void) {
  return [NSString stringWithFormat:@"/tmp/rice_theme_%u.json", getuid()];
}
