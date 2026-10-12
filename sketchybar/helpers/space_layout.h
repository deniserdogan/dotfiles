// GPL-3.0. Shared geometry keeps initial rendering and native hover identical.
#pragma once
#import <Foundation/Foundation.h>

enum { RICE_STACK_VISIBLE = 3, RICE_SPACE_END_INSET = 4, RICE_SPACE_APP_INSET = 5 };

static inline NSInteger rice_space_app_width(BOOL open) { return open ? 21 : 18; }

static inline void rice_space_primary_layout(NSMutableArray *args, NSString *owner, NSDictionary *plan, BOOL open) {
  BOOL multiple = [plan[@"appCount"] integerValue] > 1;
  NSInteger slot = multiple ? rice_space_app_width(open) : 23;
  NSInteger inset = multiple ? RICE_SPACE_APP_INSET : 0;
  [args addObjectsFromArray:@[@"--set", owner,
    [NSString stringWithFormat:@"width=%ld", [plan[@"iconWidth"] integerValue] + inset + slot],
    // SketchyBar's fixed text width includes its padding.
    [NSString stringWithFormat:@"label.width=%ld", inset + slot],
    [NSString stringWithFormat:@"label.padding_left=%ld", inset], @"label.padding_right=0"]];
}

static inline NSString *rice_space_group_name(NSString *owner) {
  return [@"space_group." stringByAppendingString:[owner substringFromIndex:6]];
}

static inline BOOL rice_space_child_visible(NSUInteger index, BOOL open) {
  return open || index < RICE_STACK_VISIBLE;
}

static inline NSInteger rice_space_overflow(NSInteger count, BOOL open) {
  return open ? 0 : MAX(0, count - RICE_STACK_VISIBLE);
}

static inline void rice_space_child_layout(NSMutableArray *args, NSString *name, NSUInteger index, BOOL open) {
  BOOL visible = rice_space_child_visible(index, open);
  // Leave breathing room even when compact. Hover adds only three pixels per
  // logo, with one baseline and one continuous bracket background.
  [args addObjectsFromArray:@[@"--set", name,
    open ? @"width=21" : visible ? @"width=18" : @"width=0",
    open ? @"icon.width=21" : visible ? @"icon.width=18" : @"icon.width=0",
    @"padding_left=0", @"padding_right=0",
    @"y_offset=0", @"background.drawing=off", @"background.border_width=0"]];
}

static inline void rice_space_badge_layout(NSMutableArray *args, NSString *name, NSInteger count, BOOL open) {
  NSInteger remainder = rice_space_overflow(count, open);
  // The existing trailing item also supplies an internal end inset. Padding
  // alone is ignored on a zero-width item, so reserve real geometry instead.
  [args addObjectsFromArray:@[@"--set", name,
    [NSString stringWithFormat:@"width=%d", (remainder ? 24 : 0) + RICE_SPACE_END_INSET],
    remainder ? @"label.width=24" : @"label.width=0",
    [NSString stringWithFormat:@"label=+%ld", remainder], @"background.drawing=off"]];
}
