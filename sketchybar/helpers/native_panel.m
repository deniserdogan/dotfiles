// GPL-3.0. Native AppKit control center and theme gallery, opened over Mach IPC.
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <signal.h>
#include <fcntl.h>
#include "native_ipc.h"
#include "theme_catalog.h"
#include "theme_preview.h"
#include "panel_status.h"
#include "personal_assets.h"
#include "appearance_wallpaper.h"
#include "ghostty_settings.h"

static NSString *directory;
static const char *panelPort = "com.denis.sketchybar.native_panel";

@interface RiceView : NSView
@property(copy) void (^keyHandler)(NSEvent *);
@end
@implementation RiceView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown:(NSEvent *)event { if (self.keyHandler) self.keyHandler(event); else [super keyDown:event]; }
@end

@interface RicePanel : NSPanel
@property(copy) void (^dismiss)(void);
@end
@implementation RicePanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
- (void)cancelOperation:(id)sender { (void)sender; if (self.dismiss) self.dismiss(); }
@end

static NSBezierPath *rice_centered_checkmark(NSRect badge) {
  NSBezierPath *mark = [NSBezierPath bezierPath];
  [mark moveToPoint:NSMakePoint(NSMidX(badge)-4.5, NSMidY(badge))];
  [mark lineToPoint:NSMakePoint(NSMidX(badge)-1.5, NSMidY(badge)+3.5)];
  [mark lineToPoint:NSMakePoint(NSMidX(badge)+4.5, NSMidY(badge)-3.5)];
  mark.lineWidth = 1.8; mark.lineCapStyle = NSLineCapStyleRound; mark.lineJoinStyle = NSLineJoinStyleRound;
  return mark;
}

typedef struct { NSRect icon, title, subtitle, preview; } RiceActionLayout;

static RiceActionLayout rice_action_layout(NSRect bounds, BOOL preview, BOOL subtitle) {
  CGFloat titleHeight = ceil([@"Ag" sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]}].height);
  CGFloat subtitleHeight = subtitle ? ceil([@"Ag" sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10]}].height) : 0;
  CGFloat gap = subtitle ? 4 : 0;
  CGFloat top = NSMidY(bounds) - (titleHeight + gap + subtitleHeight)/2;
  CGFloat textWidth = bounds.size.width - (preview ? 157 : 58);
  return (RiceActionLayout){
    .icon = NSMakeRect(15, NSMidY(bounds)-10.5, 21, 21),
    .title = NSMakeRect(47, top, textWidth, titleHeight),
    .subtitle = NSMakeRect(47, top+titleHeight+gap, textWidth, subtitleHeight),
    .preview = NSMakeRect(bounds.size.width-98, NSMidY(bounds)-25, 88, 50)
  };
}

@interface RiceButton : NSButton
@property(copy) void (^handler)(void);
@property(strong) NSDictionary *theme;
@property(strong) NSImage *preview;
@property(copy) NSString *subtitle;
@property(copy) NSString *symbol;
@property(strong) NSURL *assetURL;
@property BOOL artwork, logoArtwork;
@property BOOL hovered, chosen;
@property(strong) NSTrackingArea *tracking;
@end
@implementation RiceButton
- (instancetype)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.bordered = NO; self.target = self; self.action = @selector(fire:);
    self.focusRingType = NSFocusRingTypeNone;
    [self setButtonType:NSButtonTypeMomentaryChange];
  }
  return self;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { self.needsDisplay = YES; return YES; }
- (BOOL)resignFirstResponder { self.needsDisplay = YES; return YES; }
- (void)fire:(id)sender { (void)sender; if (self.handler) self.handler(); }
- (void)updateTrackingAreas {
  [super updateTrackingAreas];
  if (self.tracking) [self removeTrackingArea:self.tracking];
  self.tracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:nil];
  [self addTrackingArea:self.tracking];
}
- (void)mouseEntered:(NSEvent *)event { (void)event; self.hovered = YES; self.needsDisplay = YES; }
- (void)mouseExited:(NSEvent *)event { (void)event; self.hovered = NO; self.needsDisplay = YES; }
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor]; }
- (void)drawRect:(NSRect)dirty {
  (void)dirty;
  BOOL focus = self.window.firstResponder == self;
  NSColor *accent = self.theme ? rice_rgb(self.theme[@"colors"][@"blue"]) : NSColor.controlAccentColor;
  NSColor *fill = [NSColor.controlBackgroundColor colorWithAlphaComponent:self.hovered || self.highlighted ? .93 : .64];
  rice_fill(NSInsetRect(self.bounds, 1, 1), 13, fill);
  NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 1, 1) xRadius:13 yRadius:13];
  [(self.chosen || focus ? accent : [NSColor.separatorColor colorWithAlphaComponent:.35]) setStroke];
  outline.lineWidth = self.chosen || focus ? 2 : .75; [outline stroke];
  if (self.artwork) {
    NSRect preview = NSMakeRect(9, 9, self.bounds.size.width-18, 111);
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:preview xRadius:8 yRadius:8] addClip];
    rice_fill(preview, 8, self.logoArtwork ? [NSColor colorWithWhite:.94 alpha:1] : NSColor.quaternaryLabelColor);
    if (self.preview) rice_draw_fitted_image(self.preview, self.logoArtwork ? NSInsetRect(preview, 30, 16) : preview, !self.logoArtwork);
    else if (self.logoArtwork && !self.assetURL) rice_text(@"", NSMakeRect(NSMidX(preview)-23, 27, 60, 70), 57, NSFontWeightRegular, NSColor.blackColor, NO);
    else rice_text(@"…", NSMakeRect(NSMidX(preview)-8, 50, 30, 30), 20, NSFontWeightMedium, NSColor.secondaryLabelColor, NO);
    [NSGraphicsContext restoreGraphicsState];
    rice_text(self.title, NSMakeRect(13, 130, self.bounds.size.width-26, 19), 12, NSFontWeightSemibold, NSColor.labelColor, NO);
    rice_text(self.subtitle ?: @"", NSMakeRect(13, 154, self.bounds.size.width-26, 15), 10, NSFontWeightRegular, NSColor.secondaryLabelColor, NO);
  } else if (self.theme) {
    NSRect preview = NSMakeRect(9, 9, self.bounds.size.width-18, 111);
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:preview xRadius:8 yRadius:8] addClip];
    [self.preview drawInRect:preview fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
    rice_text(self.theme[@"name"], NSMakeRect(13, 130, self.bounds.size.width-38, 19), 13, NSFontWeightSemibold, NSColor.labelColor, NO);
    NSDictionary *colors = self.theme[@"colors"];
    int i = 0;
    for (NSString *key in @[@"background", @"blue", @"teal", @"green", @"yellow", @"mauve"]) {
      rice_fill(NSMakeRect(13+i*16, 156, 10, 10), 5, rice_rgb(colors[key])); i++;
    }
    rice_text([self.theme[@"mode"] capitalizedString], NSMakeRect(self.bounds.size.width-52, 154, 40, 14), 10, NSFontWeightMedium, NSColor.secondaryLabelColor, NO);
  } else {
    RiceActionLayout layout = rice_action_layout(self.bounds, self.preview != nil, self.subtitle.length > 0);
    NSImage *icon = [NSImage imageWithSystemSymbolName:self.symbol ?: @"square.grid.2x2" accessibilityDescription:nil];
    icon = [icon imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightMedium]];
    icon = [icon imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[NSColor.labelColor]]];
    [icon drawInRect:layout.icon fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:.85 respectFlipped:YES hints:nil];
    rice_text(self.title, layout.title, 12, NSFontWeightSemibold, NSColor.labelColor, NO);
    rice_text(self.subtitle ?: @"", layout.subtitle, 10, NSFontWeightRegular, NSColor.secondaryLabelColor, NO);
    if (self.preview) {
      NSRect preview = layout.preview;
      [NSGraphicsContext saveGraphicsState];
      [[NSBezierPath bezierPathWithRoundedRect:preview xRadius:7 yRadius:7] addClip];
      [self.preview drawInRect:preview fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
      [NSGraphicsContext restoreGraphicsState];
    }
  }
  if (self.chosen && (self.artwork || self.theme)) {
    NSRect badge = NSMakeRect(self.bounds.size.width-31, 15, 18, 18);
    rice_fill(badge, 9, accent);
    [NSColor.whiteColor setStroke]; [rice_centered_checkmark(badge) stroke];
  }
}
@end

@interface RiceController : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(strong) RicePanel *panel;
@property(strong) RiceView *root;
@property(strong) NSArray *catalog, *filtered;
@property(strong) NSMutableArray<RiceButton *> *cards;
@property(strong) NSMutableDictionary<NSString *, NSTextField *> *labels;
@property(strong) NSProgressIndicator *storage;
@property(strong) NSSegmentedControl *filter;
@property(strong) NSSegmentedControl *sections;
@property(strong) NSTextField *galleryStatus;
@property(strong) NSTimer *timer;
@property(strong) id globalMonitor, localMonitor;
@property(copy) NSString *page;
@property NSInteger focusIndex, filterIndex;
@property pid_t barPID;
@property BOOL snapshot;
@property BOOL choosingVPN;
@property NSRect launcherRect;
@property(strong) NSScreen *targetScreen;
@property(strong) NSArray *assetWatchers;
@property(strong) dispatch_queue_t thumbnailQueue;
@property(strong) dispatch_queue_t wallpaperQueue;
@property(strong) NSSegmentedControl *wallpaperSelector;
@property(copy) NSString *wallpaperMode;
@property BOOL wallpaperBusy;
@property(strong) NSSlider *opacitySlider, *fontSizeSlider;
@property(strong) NSTextField *opacityValue, *fontSizeValue;
@property(strong) NSTimer *ghosttyTimer;
@property BOOL ghosttyPending;
@property double ghosttyOpacity, ghosttyFontSize;
@property NSUInteger refreshGeneration;
- (void)show:(NSString *)page;
- (void)close;
@end

@implementation RiceController
- (NSTextField *)label:(NSString *)text frame:(NSRect)frame size:(CGFloat)size weight:(NSFontWeight)weight secondary:(BOOL)secondary {
  NSTextField *label = [NSTextField labelWithString:text ?: @""];
  label.frame = frame; label.font = [NSFont systemFontOfSize:size weight:weight];
  label.textColor = secondary ? NSColor.secondaryLabelColor : NSColor.labelColor;
  label.lineBreakMode = NSLineBreakByTruncatingTail;
  [self.root addSubview:label]; return label;
}
- (NSButton *)plain:(NSString *)title frame:(NSRect)frame handler:(void (^)(void))handler {
  RiceButton *button = [[RiceButton alloc] initWithFrame:frame];
  button.title = title; button.symbol = @"chevron.right"; button.handler = handler;
  button.accessibilityLabel = title; [self.root addSubview:button]; return button;
}
- (void)openApp:(NSString *)name bundle:(NSString *)identifier {
  NSURL *url = identifier ? [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:identifier] : nil;
  if (!url) url = [NSURL fileURLWithPath:[@"/Applications" stringByAppendingPathComponent:[name stringByAppendingString:@".app"]]];
  [self close];
  [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:^(NSRunningApplication *app, NSError *error) {
    (void)app; if (error) fprintf(stderr, "Open app: %s\n", error.localizedDescription.UTF8String);
  }];
}
- (NSDictionary *)currentTheme {
  NSDictionary *state = rice_json_file(rice_theme_state_path());
  return rice_theme(self.catalog, state[@"id"]) ?: rice_theme(self.catalog, @"nordfox");
}
- (NSMenu *)vpnMenu {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"VPN clients"];
  menu.autoenablesItems = NO;
  for (NSDictionary *client in @[
      @{@"title":@"INCY", @"name":@"incy", @"bundle":@"llc.itdev.incy"},
      @{@"title":@"AmneziaVPN", @"name":@"AmneziaVPN", @"bundle":@"com.yourcompany.AmneziaVPN"}]) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:client[@"title"] action:@selector(openVPNClient:) keyEquivalent:@""];
    item.target = self; item.representedObject = client;
    NSURL *url = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:client[@"bundle"]];
    if (!url) {
      NSString *appPath = [@"/Applications" stringByAppendingPathComponent:[client[@"name"] stringByAppendingString:@".app"]];
      if ([NSFileManager.defaultManager fileExistsAtPath:appPath]) url = [NSURL fileURLWithPath:appPath];
    }
    item.enabled = url != nil;
    item.toolTip = url ? @"Open this app to manage your connection" : @"This VPN client is not installed";
    if (url) { item.image = [NSWorkspace.sharedWorkspace iconForFile:url.path]; item.image.size = NSMakeSize(18, 18); }
    [menu addItem:item];
  }
  return menu;
}
- (void)chooseVPN:(NSView *)sender {
  self.choosingVPN = YES;
  [[self vpnMenu] popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSMaxY(sender.bounds)+4) inView:sender];
  self.choosingVPN = NO;
  if (!self.panel.keyWindow) [self close];
}
- (void)openVPNClient:(NSMenuItem *)sender {
  NSDictionary *client = sender.representedObject;
  [self openApp:client[@"name"] bundle:client[@"bundle"]];
}
- (void)build:(NSString *)page {
  self.page = page;
  BOOL gallery = ![page isEqual:@"control"];
  NSSize size = gallery ? NSMakeSize(744, 694) : NSMakeSize(420, 664);
  if (gallery && self.targetScreen)
    size.height = MIN(size.height, MAX(400, NSMaxY(self.targetScreen.frame)-NSMinY(self.targetScreen.visibleFrame)-63));
  self.root = [[RiceView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
  self.root.wantsLayer = YES;
  self.root.layer.cornerRadius = 20; self.root.layer.masksToBounds = YES;
  NSVisualEffectView *glass = [[NSVisualEffectView alloc] initWithFrame:self.root.bounds];
  glass.material = NSVisualEffectMaterialPopover; glass.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  glass.state = NSVisualEffectStateActive; glass.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
  [self.root addSubview:glass];
  self.labels = [NSMutableDictionary dictionary];
  self.cards = [NSMutableArray array];
  __weak RiceController *weakSelf = self;
  self.root.keyHandler = ^(NSEvent *event) {
    RiceController *self = weakSelf;
    if (event.keyCode == 53) { [self close]; return; }
    if ([self.page isEqual:@"control"] || !self.cards.count) return;
    NSInteger delta = event.keyCode == 123 ? -1 : event.keyCode == 124 ? 1 : event.keyCode == 125 ? 3 : event.keyCode == 126 ? -3 : 0;
    if (delta) {
      self.focusIndex = MAX(0, MIN((NSInteger)self.cards.count-1, self.focusIndex+delta));
      [self.panel makeFirstResponder:self.root];
      for (NSUInteger i = 0; i < self.cards.count; i++) self.cards[i].needsDisplay = YES;
      [self.cards[self.focusIndex] scrollRectToVisible:self.cards[self.focusIndex].bounds];
      self.cards[self.focusIndex].highlighted = YES;
      for (NSUInteger i = 0; i < self.cards.count; i++) if ((NSInteger)i != self.focusIndex) self.cards[i].highlighted = NO;
    } else if (event.keyCode == 36 || event.keyCode == 76) [self.cards[self.focusIndex] performClick:nil];
  };
  if ([page isEqual:@"themes"]) [self buildGallery];
  else if ([page isEqual:@"terminal"]) [self buildTerminal];
  else if (gallery) [self buildAssets];
  else [self buildControl];
  self.focusIndex = MAX(0, MIN(self.focusIndex, (NSInteger)self.cards.count-1));
  self.panel.contentView = self.root;
  [self.panel setContentSize:size];
  [self.panel recalculateKeyViewLoop];
}
- (void)buildControl {
  __weak RiceController *weakSelf = self;
  NSDateFormatter *date = [NSDateFormatter new]; date.dateFormat = @"EEEE, d MMMM";
  [self label:[[date stringFromDate:NSDate.date] uppercaseString] frame:NSMakeRect(24, 23, 330, 16) size:10 weight:NSFontWeightSemibold secondary:YES];
  [self label:@"Your Mac, at a glance" frame:NSMakeRect(24, 46, 365, 30) size:23 weight:NSFontWeightBold secondary:NO];
  NSString *machine = NSHost.currentHost.localizedName ?: @"This Mac";
  [self label:machine frame:NSMakeRect(24, 80, 360, 18) size:12 weight:NSFontWeightRegular secondary:YES];
  NSDictionary *theme = [self currentTheme];
  RiceButton *hero = [[RiceButton alloc] initWithFrame:NSMakeRect(22, 119, 376, 70)];
  hero.title = @"Personalize your desktop"; hero.subtitle = [NSString stringWithFormat:@"%lu themes · Wallpapers · Terminal", self.catalog.count];
  hero.preview = rice_theme_preview(theme);
  hero.symbol = @"paintpalette"; hero.handler = ^{ [weakSelf show:@"themes"]; }; hero.accessibilityLabel = @"Explore themes";
  [self.root addSubview:hero];
  [self label:@"SYSTEM HEALTH" frame:NSMakeRect(24, 211, 300, 16) size:10 weight:NSFontWeightSemibold secondary:YES];
  NSArray *names = @[@"Processor", @"Memory", @"Battery"];
  NSArray *keys = @[@"cpu", @"memory", @"battery"], *details = @[@"load", @"memoryDetail", @"powerDetail"];
  for (int i = 0; i < 3; i++) {
    RiceView *tile = [[RiceView alloc] initWithFrame:NSMakeRect(22+i*129, 238, 118, 91)];
    tile.wantsLayer = YES; tile.layer.backgroundColor = [rice_rgb(theme[@"colors"][@"surface"]) colorWithAlphaComponent:.82].CGColor;
    tile.layer.cornerRadius = 13; [self.root addSubview:tile];
    [self label:names[i] frame:NSMakeRect(34+i*129, 248, 103, 16) size:10 weight:NSFontWeightMedium secondary:YES];
    self.labels[keys[i]] = [self label:@"—" frame:NSMakeRect(34+i*129, 267, 103, 30) size:25 weight:NSFontWeightSemibold secondary:NO];
    self.labels[details[i]] = [self label:@"" frame:NSMakeRect(34+i*129, 305, 103, 14) size:9 weight:NSFontWeightRegular secondary:YES];
  }
  self.labels[@"storage"] = [self label:@"Storage" frame:NSMakeRect(24, 350, 370, 17) size:11 weight:NSFontWeightMedium secondary:NO];
  self.storage = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(24, 375, 372, 6)];
  self.storage.indeterminate = NO; self.storage.minValue = 0; self.storage.maxValue = 1;
  self.storage.style = NSProgressIndicatorStyleBar; [self.root addSubview:self.storage];
  self.labels[@"displays"] = [self label:@"" frame:NSMakeRect(24, 398, 370, 18) size:11 weight:NSFontWeightRegular secondary:YES];
  self.labels[@"vpn"] = [self label:@"" frame:NSMakeRect(24, 422, 370, 18) size:11 weight:NSFontWeightRegular secondary:YES];
  [self label:@"QUICK ACCESS" frame:NSMakeRect(24, 460, 300, 16) size:10 weight:NSFontWeightSemibold secondary:YES];
  NSArray *actions = @[
    @[@"Applications", @"Your installed apps", @"square.grid.2x2"],
    @[@"System Settings", @"Preferences & controls", @"gearshape"],
    @[@"Activity Monitor", @"Processes & resources", @"waveform.path.ecg"],
    @[@"VPN clients", @"INCY · AmneziaVPN", @"shield.lefthalf.filled"]];
  for (NSUInteger i = 0; i < actions.count; i++) {
    RiceButton *button = [[RiceButton alloc] initWithFrame:NSMakeRect(22+(i%2)*194, 486+(i/2)*64, 182, 57)];
    button.title = actions[i][0]; button.subtitle = actions[i][1]; button.symbol = actions[i][2];
    button.accessibilityLabel = actions[i][0];
    button.handler = ^{
      if (i == 0) { [weakSelf close]; [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:@"/Applications"]]; }
      else if (i == 1) [weakSelf openApp:@"System Settings" bundle:@"com.apple.systempreferences"];
      else if (i == 2) [weakSelf openApp:@"Activity Monitor" bundle:@"com.apple.ActivityMonitor"];
    };
    if (i == 3) {
      button.handler = nil; button.target = self; button.action = @selector(chooseVPN:);
      button.toolTip = @"Open INCY or AmneziaVPN to manage your connection";
    }
    [self.root addSubview:button];
  }
  NSButton *appearance = [NSButton buttonWithTitle:[theme[@"mode"] isEqual:@"dark"] ? @"☀  Light appearance" : @"☾  Dark appearance" target:self action:@selector(toggleAppearance:)];
  appearance.frame = NSMakeRect(24, 629, 180, 24); appearance.bezelStyle = NSBezelStyleInline;
  appearance.font = [NSFont systemFontOfSize:11]; [self.root addSubview:appearance];
  NSButton *sleep = [NSButton buttonWithTitle:@"Sleep display" target:self action:@selector(sleepDisplay:)];
  sleep.frame = NSMakeRect(270, 629, 125, 24); sleep.bezelStyle = NSBezelStyleInline;
  sleep.font = [NSFont systemFontOfSize:11]; [self.root addSubview:sleep];
  [self updateStatus];
}
- (void)toggleAppearance:(id)sender {
  (void)sender;
  rice_post("com.denis.sketchybar.native_theme", @{@"SENDER":@"--toggle"});
}
- (void)sleepDisplay:(id)sender {
  (void)sender; [self close];
  NSTask *task = [NSTask new]; task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/pmset"];
  task.arguments = @[@"displaysleepnow"]; [task launchAndReturnError:NULL];
}
- (void)updateStatus {
  if (![self.page isEqual:@"control"]) return;
  NSDictionary *status = rice_status();
  for (NSString *key in self.labels) if ([status[key] isKindOfClass:NSString.class]) self.labels[key].stringValue = status[key];
  self.labels[@"storage"].stringValue = [@"Storage  ·  " stringByAppendingString:status[@"storage"]];
  self.labels[@"vpn"].stringValue = rice_vpn_summary([status[@"vpn"] boolValue], [status[@"proxy"] boolValue]);
  self.labels[@"vpn"].textColor = [status[@"vpn"] boolValue] ? NSColor.systemGreenColor :
    [status[@"proxy"] boolValue] ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
  self.storage.doubleValue = [status[@"storageUsed"] doubleValue];
}
- (void)buildGalleryHeader {
  NSButton *back = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"Back to Control Center"] target:self action:@selector(back:)];
  back.frame = NSMakeRect(20, 25, 30, 28); back.bezelStyle = NSBezelStyleTexturedRounded; [self.root addSubview:back];
  [self label:@"Make it yours" frame:NSMakeRect(63, 23, 450, 32) size:24 weight:NSFontWeightBold secondary:NO];
  NSButton *done = [NSButton buttonWithTitle:@"Done" target:self action:@selector(done:)];
  done.frame = NSMakeRect(649, 25, 72, 27); done.bezelStyle = NSBezelStyleRounded; done.keyEquivalent = @"\e"; [self.root addSubview:done];
  self.sections = [NSSegmentedControl segmentedControlWithLabels:@[@"Themes", @"Wallpapers", @"Launcher Logo", @"Terminal"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(sectionChanged:)];
  self.sections.frame = NSMakeRect(22, 68, 430, 25);
  self.sections.selectedSegment = [@[@"themes", @"wallpapers", @"logos", @"terminal"] indexOfObject:self.page];
  [self.root addSubview:self.sections];
}
- (void)sectionChanged:(NSSegmentedControl *)sender {
  self.focusIndex = 0;
  [self show:@[@"themes", @"wallpapers", @"logos", @"terminal"][sender.selectedSegment]];
}
- (void)buildTerminal {
  [self buildGalleryHeader];
  NSUInteger headerCount = self.root.subviews.count;
  NSDictionary *values = rice_ghostty_settings(directory);
  if (!self.ghosttyPending) {
    self.ghosttyOpacity = [values[@"opacity"] doubleValue];
    self.ghosttyFontSize = [values[@"fontSize"] doubleValue];
  }
  [self label:@"Ghostty" frame:NSMakeRect(30, 121, 500, 32) size:23 weight:NSFontWeightBold secondary:NO];
  [self label:@"Your terminal, tuned to you." frame:NSMakeRect(30, 161, 660, 20) size:13 weight:NSFontWeightRegular secondary:YES];
  RiceView *surface = [[RiceView alloc] initWithFrame:NSMakeRect(24, 209, 696, 225)];
  surface.wantsLayer = YES; surface.layer.cornerRadius = 14;
  surface.layer.backgroundColor = [NSColor.controlBackgroundColor colorWithAlphaComponent:.65].CGColor;
  [self.root addSubview:surface];
  [self label:@"Background opacity" frame:NSMakeRect(42, 227, 400, 20) size:13 weight:NSFontWeightSemibold secondary:NO];
  self.opacityValue = [self label:[NSString stringWithFormat:@"%.0f%%", self.ghosttyOpacity*100]
    frame:NSMakeRect(612, 227, 80, 20) size:13 weight:NSFontWeightMedium secondary:NO];
  self.opacityValue.alignment = NSTextAlignmentRight;
  self.opacitySlider = [NSSlider sliderWithValue:self.ghosttyOpacity*100 minValue:0 maxValue:100 target:self action:@selector(ghosttySliderChanged:)];
  self.opacitySlider.frame = NSMakeRect(42, 263, 650, 24); self.opacitySlider.continuous = YES;
  self.opacitySlider.accessibilityLabel = @"Ghostty background opacity";
  [self.root addSubview:self.opacitySlider];
  [self label:@"Transparent" frame:NSMakeRect(42, 292, 300, 16) size:10 weight:NSFontWeightRegular secondary:YES];
  NSTextField *opaque = [self label:@"Opaque" frame:NSMakeRect(542, 292, 150, 16) size:10 weight:NSFontWeightRegular secondary:YES];
  opaque.alignment = NSTextAlignmentRight;
  [self label:@"Font size" frame:NSMakeRect(42, 331, 400, 20) size:13 weight:NSFontWeightSemibold secondary:NO];
  self.fontSizeValue = [self label:[NSString stringWithFormat:@"%.1f pt", self.ghosttyFontSize]
    frame:NSMakeRect(592, 331, 100, 20) size:13 weight:NSFontWeightMedium secondary:NO];
  self.fontSizeValue.alignment = NSTextAlignmentRight;
  self.fontSizeSlider = [NSSlider sliderWithValue:self.ghosttyFontSize minValue:8 maxValue:40 target:self action:@selector(ghosttySliderChanged:)];
  self.fontSizeSlider.frame = NSMakeRect(42, 367, 650, 24); self.fontSizeSlider.continuous = YES;
  self.fontSizeSlider.accessibilityLabel = @"Ghostty font size in points";
  [self.root addSubview:self.fontSizeSlider];
  [self label:@"8 pt" frame:NSMakeRect(42, 396, 300, 16) size:10 weight:NSFontWeightRegular secondary:YES];
  NSTextField *large = [self label:@"40 pt" frame:NSMakeRect(542, 396, 150, 16) size:10 weight:NSFontWeightRegular secondary:YES];
  large.alignment = NSTextAlignmentRight;
  NSTextField *note = [NSTextField wrappingLabelWithString:@"Opacity and font size update live and save automatically on this Mac. Manually zoomed tabs keep their zoom (⌘0 resets it). Native fullscreen remains opaque."];
  note.frame = NSMakeRect(32, 453, 680, 66); note.font = [NSFont systemFontOfSize:11];
  note.textColor = NSColor.secondaryLabelColor; [self.root addSubview:note];
  // The same panel works on short external displays without clipping controls.
  CGFloat scrollHeight = self.root.bounds.size.height - 149;
  NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 108, 744, scrollHeight)];
  scroll.drawsBackground = NO; scroll.hasVerticalScroller = YES; scroll.autohidesScrollers = YES;
  RiceView *content = [[RiceView alloc] initWithFrame:NSMakeRect(0, 0, 744, MAX(scrollHeight, 430))];
  NSArray *controls = [self.root.subviews subarrayWithRange:NSMakeRange(headerCount, self.root.subviews.count-headerCount)];
  for (NSView *view in controls) {
    [view removeFromSuperview]; view.frame = NSOffsetRect(view.frame, 0, -108); [content addSubview:view];
  }
  scroll.documentView = content; [self.root addSubview:scroll];
  self.galleryStatus = [self label:@"Machine-local settings · Kept across light/dark switches"
    frame:NSMakeRect(24, self.root.bounds.size.height-26, 690, 17) size:10 weight:NSFontWeightRegular secondary:YES];
}
- (void)ghosttySliderChanged:(NSSlider *)sender {
  double previousOpacity = self.ghosttyOpacity, previousFontSize = self.ghosttyFontSize;
  if (sender == self.opacitySlider) self.ghosttyOpacity = round(sender.doubleValue)/100;
  else if (sender == self.fontSizeSlider) self.ghosttyFontSize = round(sender.doubleValue*2)/2;
  else return;
  self.opacityValue.stringValue = [NSString stringWithFormat:@"%.0f%%", self.ghosttyOpacity*100];
  self.fontSizeValue.stringValue = [NSString stringWithFormat:@"%.1f pt", self.ghosttyFontSize];
  if (self.ghosttyOpacity == previousOpacity && self.ghosttyFontSize == previousFontSize) return;
  self.ghosttyPending = YES;
  // Keep native dragging immediate, but coalesce disk writes and config reloads.
  if (!self.ghosttyTimer) {
    __weak RiceController *weakSelf = self;
    self.ghosttyTimer = [NSTimer timerWithTimeInterval:.15 repeats:NO block:^(NSTimer *timer) {
      (void)timer; [weakSelf flushGhosttySettings];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.ghosttyTimer forMode:NSRunLoopCommonModes];
  }
}
- (void)flushGhosttySettings {
  [self.ghosttyTimer invalidate]; self.ghosttyTimer = nil;
  if (!self.ghosttyPending) return;
  self.ghosttyPending = NO;
  NSError *error = nil;
  BOOL saved = rice_ghostty_save_settings(directory, self.ghosttyOpacity, self.ghosttyFontSize, &error);
  BOOL reloaded = saved && !self.snapshot && rice_ghostty_reload();
  if ([self.page isEqual:@"terminal"]) self.galleryStatus.stringValue = saved ?
    reloaded ? @"Saved · Terminal appearance updated" : @"Saved · Applies when Ghostty opens" :
    error.localizedDescription ?: @"Could not save terminal settings.";
}
- (void)buildGallery {
  [self buildGalleryHeader];
  NSUInteger dark = 0, light = 0;
  for (NSDictionary *theme in self.catalog) { dark += [theme[@"mode"] isEqual:@"dark"]; light += [theme[@"mode"] isEqual:@"light"]; }
  self.filter = [NSSegmentedControl segmentedControlWithLabels:@[[NSString stringWithFormat:@"All %lu", self.catalog.count],
    [NSString stringWithFormat:@"Dark %lu", dark], [NSString stringWithFormat:@"Light %lu", light]] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filterChanged:)];
  self.filter.frame = NSMakeRect(22, 108, 280, 25); self.filter.selectedSegment = self.filterIndex;
  self.filter.controlSize = NSControlSizeSmall; [self.root addSubview:self.filter];
  [self label:@"One click. A coordinated desktop." frame:NSMakeRect(409, 113, 315, 18) size:11 weight:NSFontWeightRegular secondary:YES];
  NSString *mode = self.filterIndex == 1 ? @"dark" : self.filterIndex == 2 ? @"light" : nil;
  NSMutableArray *filtered = [NSMutableArray array];
  for (NSDictionary *theme in self.catalog) if (!mode || [theme[@"mode"] isEqual:mode]) [filtered addObject:theme];
  self.filtered = filtered;
  CGFloat scrollHeight = self.root.bounds.size.height - 187;
  NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(14, 146, 716, scrollHeight)];
  scroll.drawsBackground = NO; scroll.hasVerticalScroller = YES; scroll.autohidesScrollers = YES;
  RiceView *grid = [[RiceView alloc] initWithFrame:NSMakeRect(0, 0, 716, MAX(scrollHeight, ((filtered.count+2)/3)*184))];
  NSString *active = [self currentTheme][@"id"];
  __weak RiceController *weakSelf = self;
  for (NSUInteger i = 0; i < filtered.count; i++) {
    NSDictionary *theme = filtered[i];
    RiceButton *card = [[RiceButton alloc] initWithFrame:NSMakeRect(8+(i%3)*235, (i/3)*184+2, 222, 176)];
    card.theme = theme; card.preview = rice_theme_preview(theme); card.chosen = [theme[@"id"] isEqual:active];
    card.accessibilityLabel = [NSString stringWithFormat:@"Apply %@, %@ theme", theme[@"name"], theme[@"mode"]];
    card.toolTip = theme[@"description"];
    card.handler = ^{
      RiceController *self = weakSelf;
      self.galleryStatus.stringValue = [@"Applying " stringByAppendingString:theme[@"name"]];
      if (!rice_post("com.denis.sketchybar.native_theme", @{@"SENDER":@"--select", @"ID":theme[@"id"]})) self.galleryStatus.stringValue = @"Theme service unavailable. Reload SketchyBar and try again.";
    };
    [grid addSubview:card]; [self.cards addObject:card];
  }
  scroll.documentView = grid; [self.root addSubview:scroll];
  self.galleryStatus = [self label:[NSString stringWithFormat:@"%@ active  ·  Previews are illustrative", [self currentTheme][@"name"]]
    frame:NSMakeRect(24, self.root.bounds.size.height-26, 470, 17) size:10 weight:NSFontWeightRegular secondary:YES];
  [self label:@"← ↑ ↓ → browse   ↵ apply   esc close" frame:NSMakeRect(500, self.root.bounds.size.height-26, 228, 17) size:10 weight:NSFontWeightRegular secondary:YES];
}
- (void)loadArtwork:(RiceButton *)card {
  if (!card.assetURL) return;
  if (self.snapshot) { card.preview = rice_asset_thumbnail(card.assetURL); return; }
  if (!self.thumbnailQueue) self.thumbnailQueue = dispatch_queue_create("com.denis.rice.thumbnails", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
  NSURL *url = card.assetURL;
  __weak RiceButton *weakCard = card;
  dispatch_async(self.thumbnailQueue, ^{
    // Discard queued work when the user has already left this gallery.
    if (!weakCard) return;
    NSImage *image = rice_asset_thumbnail(url);
    dispatch_async(dispatch_get_main_queue(), ^{
      RiceButton *current = weakCard;
      if (!current) return;
      current.preview = image; current.needsDisplay = YES;
      if (!image) current.subtitle = @"Cannot preview this image";
    });
  });
}
- (void)buildAssets {
  rice_prepare_assets(directory);
  [self buildGalleryHeader];
  BOOL logos = [self.page isEqual:@"logos"];
  NSArray *files = rice_asset_files(directory, self.page);
  NSDictionary *preferences = rice_personal_preferences(directory);
  if (logos) {
    NSButton *tint = [NSButton checkboxWithTitle:@"Use theme color" target:self action:@selector(logoTintChanged:)];
    tint.frame = NSMakeRect(22, 109, 190, 25);
    tint.state = [rice_personal_preferences(directory)[@"tintLogo"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    [self.root addSubview:tint];
  } else {
    if (!self.wallpaperMode) self.wallpaperMode = [self currentTheme][@"mode"];
    self.wallpaperSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"Static", @"Light", @"Dark"]
      trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(wallpaperModeChanged:)];
    self.wallpaperSelector.frame = NSMakeRect(22, 108, 240, 25);
    self.wallpaperSelector.selectedSegment = [@[@"static", @"light", @"dark"] indexOfObject:self.wallpaperMode];
    self.wallpaperSelector.enabled = !self.wallpaperBusy;
    self.wallpaperSelector.toolTip = @"Static uses one wallpaper. Light and Dark assign images that switch automatically with macOS appearance.";
    self.wallpaperSelector.accessibilityLabel = @"Wallpaper appearance assignment";
    [self.root addSubview:self.wallpaperSelector];
  }
  NSButton *refresh = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:@"Refresh images"] target:self action:@selector(refreshAssets:)];
  refresh.frame = NSMakeRect(543, 108, 31, 25); refresh.bezelStyle = NSBezelStyleTexturedRounded; [self.root addSubview:refresh];
  NSButton *folder = [NSButton buttonWithTitle:@"Open folder" target:self action:@selector(openAssetFolder:)];
  folder.frame = NSMakeRect(585, 107, 136, 27); folder.bezelStyle = NSBezelStyleRounded; [self.root addSubview:folder];
  CGFloat height = self.root.bounds.size.height - 187;
  NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(14, 146, 716, height)];
  scroll.drawsBackground = NO; scroll.hasVerticalScroller = YES; scroll.autohidesScrollers = YES;
  NSUInteger count = files.count + (logos ? 1 : 0);
  RiceView *grid = [[RiceView alloc] initWithFrame:NSMakeRect(0, 0, 716, MAX(height, ((count+2)/3)*184))];
  NSString *activeLogo = preferences[@"logo"];
  BOOL logoExists = NO;
  for (NSURL *file in files) if ([file.lastPathComponent isEqual:activeLogo]) logoExists = YES;
  if (!logoExists) activeLogo = @"";
  NSScreen *display = self.targetScreen ?: NSScreen.mainScreen;
  NSURL *wallpaper = display ? [NSWorkspace.sharedWorkspace desktopImageURLForScreen:display] : nil;
  __weak RiceController *weakSelf = self;
  for (NSUInteger i = 0; i < count; i++) {
    NSURL *url = logos && i == 0 ? nil : files[i-(logos ? 1 : 0)];
    RiceButton *card = [[RiceButton alloc] initWithFrame:NSMakeRect(8+(i%3)*235, (i/3)*184+2, 222, 176)];
    card.artwork = YES; card.logoArtwork = logos; card.assetURL = url;
    card.title = url ? url.lastPathComponent.stringByDeletingPathExtension : @"Apple (default)";
    card.subtitle = url ? url.pathExtension.uppercaseString : @"Restore the standard launcher";
    card.chosen = logos ? [activeLogo isEqual:url.lastPathComponent ?: @""] :
      [self.wallpaperMode isEqual:@"static"] ? [url.URLByStandardizingPath isEqual:wallpaper.URLByStandardizingPath] :
      rice_wallpaper_name_matches(preferences[@"wallpapers"][self.wallpaperMode], url.lastPathComponent);
    if (!logos) {
      NSMutableArray *roles = [NSMutableArray array];
      for (NSString *mode in @[@"light", @"dark"])
        if (rice_wallpaper_name_matches(preferences[@"wallpapers"][mode], url.lastPathComponent)) [roles addObject:mode.capitalizedString];
      if (roles.count) card.subtitle = [NSString stringWithFormat:@"%@ · %@", card.subtitle, [roles componentsJoinedByString:@" / "]];
      card.enabled = !self.wallpaperBusy;
    }
    card.toolTip = url ? url.lastPathComponent : @"Restore the Apple logo";
    card.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", logos ? @"Use logo" : @"Set wallpaper", card.title];
    card.handler = ^{ if (logos) [weakSelf chooseLogo:url]; else [weakSelf applyWallpaper:url]; };
    [grid addSubview:card]; [self.cards addObject:card]; [self loadArtwork:card];
  }
  if (!count) {
    NSTextField *title = [NSTextField labelWithString:@"Your wallpaper collection starts here"];
    title.frame = NSMakeRect(70, 142, 580, 35); title.alignment = NSTextAlignmentCenter;
    title.font = [NSFont systemFontOfSize:21 weight:NSFontWeightSemibold]; [grid addSubview:title];
    NSTextField *detail = [NSTextField wrappingLabelWithString:@"Download images into the Wallpapers folder.\nThey will appear here automatically—nothing is uploaded."];
    detail.frame = NSMakeRect(90, 187, 540, 62); detail.alignment = NSTextAlignmentCenter;
    detail.font = [NSFont systemFontOfSize:13]; detail.textColor = NSColor.secondaryLabelColor; [grid addSubview:detail];
  }
  scroll.documentView = grid; [self.root addSubview:scroll];
  NSString *message = logos ? @"Personal logos stay on this Mac · PNG, SVG or PDF recommended" :
    files.count ? [NSString stringWithFormat:@"%lu wallpaper%@ · %@ · All Spaces & displays", files.count, files.count == 1 ? @"" : @"s",
      [self.wallpaperMode isEqual:@"static"] ? @"One image for both appearances" : [NSString stringWithFormat:@"Assign %@ appearance", self.wallpaperMode]] :
    @"Private library · ~/.config/rice/wallpapers · Open folder to add images";
  self.galleryStatus = [self label:message frame:NSMakeRect(24, self.root.bounds.size.height-26, 690, 17) size:10 weight:NSFontWeightRegular secondary:YES];
}
- (void)wallpaperModeChanged:(NSSegmentedControl *)sender {
  if (self.wallpaperBusy) return;
  self.wallpaperMode = @[@"static", @"light", @"dark"][sender.selectedSegment];
  [self build:@"wallpapers"]; [self.panel makeFirstResponder:self.root];
}
- (void)refreshAssets:(id)sender { (void)sender; [self build:self.page]; [self.panel makeFirstResponder:self.root]; }
- (void)openAssetFolder:(id)sender {
  (void)sender; rice_prepare_assets(directory);
  NSURL *url = [NSURL fileURLWithPath:rice_asset_directory(directory, self.page) isDirectory:YES];
  [self close]; [NSWorkspace.sharedWorkspace openURL:url];
}
- (void)applyWallpaper:(NSURL *)url {
  if (self.wallpaperBusy) return;
  if (![rice_asset_files(directory, @"wallpapers") containsObject:url] || !rice_asset_thumbnail(url)) {
    self.galleryStatus.stringValue = @"Cannot open this wallpaper. Check that the image has finished downloading."; return;
  }
  BOOL automatic = ![self.wallpaperMode isEqual:@"static"];
  NSMutableDictionary *names = [rice_personal_preferences(directory)[@"wallpapers"] mutableCopy] ?: [NSMutableDictionary dictionary];
  if (automatic) {
    names[self.wallpaperMode] = url.lastPathComponent;
    // On a fresh install, one image fills both roles until a second is chosen.
    for (NSString *mode in @[@"light", @"dark"])
      if (!rice_wallpaper_source(directory, names[mode])) names[mode] = url.lastPathComponent;
  }
  NSString *config = [directory copy];
  self.wallpaperBusy = YES; self.wallpaperSelector.enabled = NO;
  for (RiceButton *card in self.cards) card.enabled = NO;
  self.galleryStatus.stringValue = automatic ? @"Preparing native light/dark wallpaper…" : @"Applying wallpaper to all Spaces…";
  if (!self.wallpaperQueue) self.wallpaperQueue = dispatch_queue_create("com.denis.rice.wallpaper", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
  dispatch_async(self.wallpaperQueue, ^{
    NSError *error = nil;
    NSURL *target = automatic ? rice_wallpaper_pair(config, names, &error) : url;
    BOOL applied = target && rice_wallpaper_apply_all_spaces(config, target, &error);
    if (applied) {
      // Re-read unrelated logo preferences after encoding, not before it.
      NSMutableDictionary *current = rice_personal_preferences(config);
      current[@"wallpapers"] = names; current[@"followAppearance"] = @(automatic);
      if (!rice_save_personal_preferences(config, current)) {
        applied = NO; rice_wallpaper_error(&error, @"Wallpaper applied, but its choices could not be saved.");
      }
    }
    NSString *message = applied ? automatic ? @"Light/dark pair applied · macOS switches it automatically · All Spaces" : @"Wallpaper applied · All Spaces & displays" : error.localizedDescription ?: @"Could not set wallpaper.";
    dispatch_async(dispatch_get_main_queue(), ^{
      self.wallpaperBusy = NO;
      if ([self.page isEqual:@"wallpapers"]) {
        [self build:@"wallpapers"]; self.galleryStatus.stringValue = message;
        [self.panel makeFirstResponder:self.root];
      }
      if (!applied) NSLog(@"Wallpaper: %@", message);
    });
  });
}
- (BOOL)applyLauncher {
  if (self.snapshot) return YES;
  NSArray *arguments = rice_launcher_arguments(directory, [self currentTheme]);
  return arguments && rice_bar(arguments);
}
- (void)chooseLogo:(NSURL *)url {
  if (url && (![rice_asset_files(directory, @"logos") containsObject:url] || !rice_asset_thumbnail(url))) {
    self.galleryStatus.stringValue = @"Cannot open this logo. Try a PNG, SVG or PDF image."; return;
  }
  NSMutableDictionary *preferences = rice_personal_preferences(directory);
  preferences[@"logo"] = url.lastPathComponent ?: @"";
  if (!rice_save_personal_preferences(directory, preferences) || ![self applyLauncher]) {
    self.galleryStatus.stringValue = @"Could not update the launcher. Check the folder permissions."; return;
  }
  for (RiceButton *card in self.cards) { card.chosen = [card.assetURL isEqual:url] || (!card.assetURL && !url); card.needsDisplay = YES; }
  self.galleryStatus.stringValue = @"Launcher updated · Your choice is saved only on this Mac";
}
- (void)logoTintChanged:(NSButton *)sender {
  NSMutableDictionary *preferences = rice_personal_preferences(directory);
  preferences[@"tintLogo"] = @(sender.state == NSControlStateValueOn);
  if (!rice_save_personal_preferences(directory, preferences) || ![self applyLauncher]) self.galleryStatus.stringValue = @"Could not update the launcher color.";
}
- (void)watchAssetFolders {
  rice_prepare_assets(directory);
  NSMutableArray *watchers = [NSMutableArray array];
  __weak RiceController *weakSelf = self;
  for (NSString *kind in @[@"wallpapers", @"logos"]) {
    int descriptor = open(rice_asset_directory(directory, kind).fileSystemRepresentation, O_EVTONLY);
    if (descriptor < 0) continue;
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, descriptor,
      DISPATCH_VNODE_WRITE|DISPATCH_VNODE_EXTEND|DISPATCH_VNODE_ATTRIB, dispatch_get_main_queue());
    dispatch_source_set_event_handler(source, ^{
      RiceController *self = weakSelf;
      NSUInteger generation = ++self.refreshGeneration;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 180 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (generation != self.refreshGeneration) return;
        [self applyLauncher];
        if (self.panel.visible && ( [self.page isEqual:@"logos"] || [self.page isEqual:@"wallpapers"])) [self build:self.page];
      });
    });
    dispatch_source_set_cancel_handler(source, ^{ close(descriptor); });
    [watchers addObject:source]; dispatch_resume(source);
  }
  self.assetWatchers = watchers;
}
- (void)filterChanged:(id)sender { (void)sender; self.filterIndex = self.filter.selectedSegment; self.focusIndex = 0; [self build:@"themes"]; [self.panel makeFirstResponder:self.root]; }
- (void)back:(id)sender { (void)sender; [self show:@"control"]; }
- (void)done:(id)sender { (void)sender; [self close]; }
- (void)inspect:(NSString *)path {
  if (![path hasPrefix:@"/tmp/"] && ![path hasPrefix:@"/private/tmp/"]) return;
  NSMutableArray *cards = [NSMutableArray array];
  for (RiceButton *card in self.cards) [cards addObject:@{@"id":card.theme[@"id"] ?: card.assetURL.lastPathComponent ?: @"default", @"selected":@(card.chosen)}];
  NSDictionary *state = @{@"page":self.page ?: @"closed", @"visible":@(self.panel.visible),
    @"themes":cards, @"filter":@(self.filterIndex), @"status":self.galleryStatus.stringValue ?: @"",
    @"wallpaperMode":self.wallpaperMode ?: @"", @"terminal":rice_ghostty_settings(directory),
    @"width":@(self.root.bounds.size.width), @"height":@(self.root.bounds.size.height)};
  [[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:NULL] writeToFile:path atomically:YES];
}
- (void)themeChanged:(NSNotification *)note {
  (void)note;
  NSDictionary *current = [self currentTheme];
  self.panel.appearance = [NSAppearance appearanceNamed:[current[@"mode"] isEqual:@"dark"] ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
  NSApp.appearance = self.panel.appearance;
  [self applyLauncher];
  if ([self.page isEqual:@"themes"]) {
    for (RiceButton *card in self.cards) { card.chosen = [card.theme[@"id"] isEqual:current[@"id"]]; card.needsDisplay = YES; }
    self.galleryStatus.stringValue = [NSString stringWithFormat:@"%@ active  ·  Previews are illustrative", current[@"name"]];
  } else if (self.panel.visible && [self.page isEqual:@"control"]) [self build:@"control"];
  else if (self.panel.visible && [self.page isEqual:@"wallpapers"]) {
    self.wallpaperMode = current[@"mode"];
    [self build:@"wallpapers"];
  }
  else if (self.panel.visible && [self.page isEqual:@"terminal"]) [self build:@"terminal"];
}
- (void)show:(NSString *)page {
  if (![page isEqual:@"terminal"]) [self flushGhosttySettings];
  // Opening the picker always targets the current appearance, not the last
  // assignment tab visited. An explicit Light/Dark/Static choice still works.
  if ([page isEqual:@"wallpapers"]) self.wallpaperMode = [self currentTheme][@"mode"];
  BOOL wasVisible = self.panel.visible;
  CGFloat previousX = self.panel.frame.origin.x;
  NSScreen *screen = NSScreen.mainScreen;
  NSPoint mouse = NSEvent.mouseLocation;
  for (NSScreen *candidate in NSScreen.screens) if (NSPointInRect(mouse, candidate.frame)) screen = candidate;
  self.targetScreen = screen;
  if (!self.panel) {
    self.panel = [[RicePanel alloc] initWithContentRect:NSMakeRect(0, 0, 420, 628) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.panel.title = @"Rice Control Center"; self.panel.level = NSFloatingWindowLevel;
    self.panel.opaque = NO; self.panel.backgroundColor = NSColor.clearColor; self.panel.hasShadow = YES;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorTransient|NSWindowCollectionBehaviorIgnoresCycle|NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.panel.hidesOnDeactivate = NO; self.panel.delegate = self;
    __weak RiceController *weakSelf = self;
    self.panel.dismiss = ^{ [weakSelf close]; };
  }
  self.panel.appearance = [NSAppearance appearanceNamed:[[self currentTheme][@"mode"] isEqual:@"dark"] ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
  NSApp.appearance = self.panel.appearance;
  [self build:page];
  NSRect frame = self.panel.frame;
  CGFloat anchorX = wasVisible ? previousX : mouse.x-35;
  frame.origin.x = MAX(NSMinX(screen.visibleFrame)+10, MIN(anchorX, NSMaxX(screen.visibleFrame)-frame.size.width-10));
  frame.origin.y = MAX(NSMinY(screen.visibleFrame)+10, NSMaxY(screen.frame)-53-frame.size.height);
  self.launcherRect = NSMakeRect(NSMinX(screen.frame)+12, NSMaxY(screen.frame)-44, 52, 38);
  [self.panel setFrame:frame display:NO];
  if (!self.snapshot) {
    self.panel.alphaValue = wasVisible ? 1 : 0;
    [self.panel makeKeyAndOrderFront:nil]; [self.panel makeFirstResponder:self.root];
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
      context.duration = .12; context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
      self.panel.animator.alphaValue = 1;
    } completionHandler:nil];
  }
}
- (void)close {
  [self flushGhosttySettings];
  [self.panel orderOut:nil]; self.panel.alphaValue = 1;
}
- (void)windowDidResignKey:(NSNotification *)note { (void)note; if (self.panel.visible && !self.choosingVPN) [self close]; }
- (void)applicationDidFinishLaunching:(NSNotification *)note {
  (void)note;
  __weak RiceController *weakSelf = self;
  [self watchAssetFolders];
  [self applyLauncher];
  self.globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown handler:^(NSEvent *event) {
    (void)event;
    // The launcher's native click event owns its toggle. Closing on mouse-down
    // here would make the subsequent mouse-up reopen the panel instead.
    if (!weakSelf.choosingVPN && !NSPointInRect(NSEvent.mouseLocation, weakSelf.launcherRect)) [weakSelf close];
  }];
  self.localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown handler:^NSEvent *(NSEvent *event) {
    if (!weakSelf.choosingVPN && event.window != weakSelf.panel) [weakSelf close]; return event;
  }];
  [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceActiveSpaceDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
    (void)n; [weakSelf close];
  }];
  [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"RiceThemeDidChange" object:@"com.denis.rice" queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { [weakSelf themeChanged:n]; }];
  [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"RiceThemeApplyFailed" object:@"com.denis.rice" queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
    weakSelf.galleryStatus.stringValue = n.userInfo[@"message"] ?: @"Could not apply theme.";
  }];
  self.timer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) {
    (void)timer;
    if (kill(weakSelf.barPID, 0) != 0) [NSApp terminate:nil];
    if (weakSelf.panel.visible) [weakSelf updateStatus];
  }];
}
@end

static BOOL export_view(RiceController *controller, NSString *page, NSString *path) {
  controller.snapshot = YES; [controller show:page];
  [controller.root layoutSubtreeIfNeeded];
  NSBitmapImageRep *bitmap = [controller.root bitmapImageRepForCachingDisplayInRect:controller.root.bounds];
  [controller.root cacheDisplayInRect:controller.root.bounds toBitmapImageRep:bitmap];
  return [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

int main(int argc, char **argv) {
  @autoreleasepool {
    const char *config = getenv("CONFIG_DIR");
    directory = config && *config ? @(config) : [NSHomeDirectory() stringByAppendingPathComponent:@".config/sketchybar"];
    if (argc == 2 && (!strcmp(argv[1], "--toggle") || !strcmp(argv[1], "--themes") || !strcmp(argv[1], "--wallpapers") || !strcmp(argv[1], "--logos") || !strcmp(argv[1], "--terminal") || !strcmp(argv[1], "--close")))
      return rice_post(panelPort, @{@"SENDER":@(argv[1])}) ? 0 : 1;
    if (argc == 3 && !strcmp(argv[1], "--inspect"))
      return rice_post(panelPort, @{@"SENDER":@"--inspect", @"PATH":@(argv[2])}) ? 0 : 1;
    BOOL snapshot = argc == 4 && !strcmp(argv[1], "--snapshot");
    BOOL daemon = argc == 3 && !strcmp(argv[1], "--run");
    if (!snapshot && (argc != 3 || (strcmp(argv[1], "--ensure") && !daemon))) return 2;
    pid_t barPID = snapshot ? getpid() : (pid_t)strtol(argv[2], NULL, 10);
    if (!snapshot && !daemon && rice_post(panelPort, @{@"SENDER":@"--rebind", @"BAR_PID":@(argv[2])})) return 0;
    if (!snapshot && !daemon) {
      char *args[] = {argv[0], "--run", argv[2], NULL};
      pid_t child = fork(); if (child < 0) return 1;
      if (!child) { setsid(); execv(argv[0], args); _exit(127); }
        for (int i = 0; i < 200; i++) {
          mach_port_t port = rice_lookup(panelPort);
          if (port) { mach_port_deallocate(mach_task_self(), port); return 0; }
          usleep(10000);
        }
        return 1;
    }
    if (!snapshot) {
      freopen("/dev/null", "r", stdin); freopen("/dev/null", "w", stdout);
      NSString *log = [NSString stringWithFormat:@"/tmp/sketchybar_native_panel_%u.log", getuid()];
      freopen(log.UTF8String, "a", stderr); setvbuf(stderr, NULL, _IONBF, 0);
    }
    [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    RiceController *controller = [RiceController new]; controller.barPID = barPID;
    controller.catalog = rice_themes(directory);
    if (!controller.catalog) return 1;
    [NSApp setDelegate:controller];
    if (snapshot) return export_view(controller, @(argv[2]), @(argv[3])) ? 0 : 1;
    mach_port_t port = rice_register(panelPort); if (!port) return 1;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
      for (;;) {
        struct mach_buffer buffer; mach_receive_message(port, &buffer, true);
        if (!buffer.message.descriptor.address) continue;
        if (buffer.message.descriptor.size != 2) {
          @autoreleasepool {
            env event = buffer.message.descriptor.address;
            NSString *sender = @(env_get_value_for_key(event, "SENDER"));
            NSString *path = @(env_get_value_for_key(event, "PATH"));
            pid_t pid = (pid_t)strtol(env_get_value_for_key(event, "BAR_PID"), NULL, 10);
            dispatch_async(dispatch_get_main_queue(), ^{
              if ([sender isEqual:@"--rebind"] && pid > 1) {
                if (pid != controller.barPID && g_mach_port) { mach_port_deallocate(mach_task_self(), g_mach_port); g_mach_port = MACH_PORT_NULL; }
                controller.barPID = pid; [controller close];
              }
              else if ([sender isEqual:@"--inspect"]) [controller inspect:path];
              else if ([sender isEqual:@"--close"]) [controller close];
              else if ([sender isEqual:@"--themes"]) [controller show:@"themes"];
              else if ([sender isEqual:@"--wallpapers"]) [controller show:@"wallpapers"];
              else if ([sender isEqual:@"--logos"]) [controller show:@"logos"];
              else if ([sender isEqual:@"--terminal"]) [controller show:@"terminal"];
              else if ([sender isEqual:@"--toggle"]) {
                if (controller.panel.visible) [controller close]; else [controller show:@"control"];
              }
            });
          }
        }
        mach_msg_destroy(&buffer.message.header);
      }
    });
    fprintf(stderr, "Native panel ready for SketchyBar PID %d\n", barPID);
    [NSApp run];
  }
  return 0;
}
