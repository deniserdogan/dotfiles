// Internal AppKit view checks. Never clicks an action or changes the desktop.
#define main rice_panel_application_main
#include "../native_panel.m"
#undef main

@interface RiceTestController : RiceController
@property NSUInteger assetNotifications;
@property(copy) NSString *testMode;
@end
@implementation RiceTestController
- (BOOL)applyLauncher { self.assetNotifications++; return YES; }
- (NSDictionary *)currentTheme {
  if (self.testMode) for (NSDictionary *theme in self.catalog)
    if ([theme[@"mode"] isEqual:self.testMode]) return theme;
  return [super currentTheme];
}
@end

static void check(BOOL condition, NSString *message) {
  if (!condition) {
    fprintf(stderr, "FAIL: %s\n", message.UTF8String);
    exit(1);
  }
}

static BOOL containsLabel(NSView *view, NSString *text) {
  if ([view isKindOfClass:NSTextField.class] && [((NSTextField *)view).stringValue containsString:text]) return YES;
  for (NSView *child in view.subviews) if (containsLabel(child, text)) return YES;
  return NO;
}

static void key(RiceController *controller, unsigned short code) {
  NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
    modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@""
    charactersIgnoringModifiers:@"" isARepeat:NO keyCode:code];
  controller.root.keyHandler(event);
}

int main(void) {
  @autoreleasepool {
    directory = @(getenv("CONFIG_DIR"));
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSRect badge = NSMakeRect(191, 15, 18, 18);
    NSRect mark = rice_centered_checkmark(badge).bounds;
    check(NSMidX(mark) == NSMidX(badge) && NSMidY(mark) == NSMidY(badge), @"Selection checkmark is centered inside its badge without font-baseline offsets");
    for (NSNumber *height in @[@57, @70]) {
      NSRect bounds = NSMakeRect(0, 0, 376, height.doubleValue);
      RiceActionLayout layout = rice_action_layout(bounds, height.intValue == 70, YES);
      NSRect text = NSUnionRect(layout.title, layout.subtitle);
      check(NSMidY(text) == NSMidY(bounds) && NSMidY(layout.icon) == NSMidY(bounds) &&
        NSMidY(layout.preview) == NSMidY(bounds), @"Action-card text, symbol and artwork share the vertical center at both card heights");
      if (height.intValue == 70)
        check(NSMaxX(text)+12 <= NSMinX(layout.preview), @"Personalization text retains clearance from its preview");
    }
    RiceTestController *controller = [RiceTestController new];
    controller.catalog = rice_themes(directory);
    NSUInteger darkCount = 0, lightCount = 0;
    for (NSDictionary *theme in controller.catalog) { darkCount += [theme[@"mode"] isEqual:@"dark"]; lightCount += [theme[@"mode"] isEqual:@"light"]; }
    check(controller.catalog.count >= 18 && lightCount >= 10, @"Expanded catalog loads");
    for (NSString *appearance in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
      [[NSAppearance appearanceNamed:appearance] performAsCurrentDrawingAppearance:^{
        for (NSDictionary *theme in controller.catalog) {
          NSImage *preview = rice_theme_preview(theme);
          check(preview.isValid && preview.representations.count == 1 &&
            [preview.representations[0] isKindOfClass:NSBitmapImageRep.class], @"Theme previews cache pixels, not appearance-dependent drawing handlers");
          check(rice_theme_preview(theme) == preview, @"Theme preview is rendered only once");
          NSBitmapImageRep *target = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:360 pixelsHigh:200
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
          [NSGraphicsContext saveGraphicsState];
          [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:target]];
          [preview drawInRect:NSMakeRect(0, 0, 360, 200)];
          [NSGraphicsContext restoreGraphicsState];
        }
      }];
    }
    controller.snapshot = YES;
    [controller show:@"themes"];
    check(controller.cards.count == controller.catalog.count, @"All filter shows every theme");
    BOOL reachedLight = NO;
    for (RiceButton *card in controller.cards) {
      if ([card.theme[@"mode"] isEqual:@"light"]) reachedLight = YES;
      else check(!reachedLight, @"All gallery groups every dark theme before the light themes");
    }
    NSUInteger chosen = 0;
    for (RiceButton *card in controller.cards) chosen += card.chosen;
    check(chosen == 1, @"Exactly one active theme");
    key(controller, 124);
    check(controller.focusIndex == 1 && controller.cards[1].highlighted, @"Right arrow advances focus");
    key(controller, 125);
    check(controller.focusIndex == 4, @"Down arrow advances one grid row");
    key(controller, 126);
    check(controller.focusIndex == 1, @"Up arrow returns one grid row");
    controller.filter.selectedSegment = 1;
    [controller filterChanged:nil];
    check(controller.cards.count == darkCount && controller.focusIndex == 0, @"Dark filter resets focus and shows dark themes");
    for (RiceButton *card in controller.cards) check([card.theme[@"mode"] isEqual:@"dark"], @"Dark filter excludes light themes");
    controller.filter.selectedSegment = 2;
    [controller filterChanged:nil];
    check(controller.cards.count == lightCount, @"Light filter shows every light theme");
    for (RiceButton *card in controller.cards) check([card.theme[@"mode"] isEqual:@"light"], @"Light filter excludes dark themes");
    [controller back:nil];
    check([controller.page isEqual:@"control"], @"Back opens Control Center");
    for (NSView *view in controller.root.subviews)
      check(NSContainsRect(controller.root.bounds, view.frame), @"Control content stays within panel bounds");
    check(controller.labels[@"storage"].stringValue.length > 10, @"Native telemetry populates");
    NSMenu *vpn = [controller vpnMenu];
    check(vpn.numberOfItems == 2, @"Both VPN clients are available in one native menu");
    check([vpn.itemArray[0].title isEqual:@"INCY"] && [vpn.itemArray[1].title isEqual:@"AmneziaVPN"], @"VPN client names");
    check([vpn.itemArray[0].representedObject[@"bundle"] isEqual:@"llc.itdev.incy"], @"INCY resolves by its installed bundle identifier");
    check(!rice_proxy_enabled(@{}) && !rice_proxy_enabled(@{@"HTTPEnable":@0}), @"Absent and disabled proxies are inactive");
    for (NSString *name in @[@"HTTPEnable", @"HTTPSEnable", @"SOCKSEnable", @"ProxyAutoConfigEnable", @"ProxyAutoDiscoveryEnable"])
      check(rice_proxy_enabled(@{name:@1}), @"System proxy modes are detected");
    check([rice_vpn_summary(NO, YES) containsString:@"System proxy enabled"], @"Proxy mode is not falsely called a VPN tunnel");
    check(![rice_vpn_summary(YES, NO) containsString:@"Amnezia"], @"Tunnel status never guesses the provider");
    check([rice_vpn_summary(NO, NO) containsString:@"No VPN tunnel or system proxy"], @"Disconnected status describes detection only");
    // Asset fixtures live outside the real library; no wallpaper is applied.
    NSString *originalDirectory = directory;
    NSString *temporary = [@"/private/tmp" stringByAppendingPathComponent:[@"rice-assets-test-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    directory = [temporary stringByAppendingPathComponent:@"sketchybar"];
    rice_prepare_assets(directory);
    [controller show:@"wallpapers"];
    check(!controller.cards.count, @"Empty wallpaper folder has a useful empty state");
    [controller watchAssetFolders];
    NSString *wallpaperPath = [rice_asset_directory(directory, @"wallpapers") stringByAppendingPathComponent:@"Sample.png"];
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1200 pixelsHigh:600
      bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:wallpaperPath atomically:YES];
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.35]];
    check(controller.assetNotifications == 1, @"Native folder notifications are debounced without reloading the bar");
    [NSFileManager.defaultManager createSymbolicLinkAtPath:[rice_asset_directory(directory, @"wallpapers") stringByAppendingPathComponent:@"Link.png"] withDestinationPath:wallpaperPath error:NULL];
    check(rice_asset_files(directory, @"wallpapers").count == 1, @"Only real image files enter the library");
    NSImage *thumbnail = rice_asset_thumbnail([NSURL fileURLWithPath:wallpaperPath]);
    check(thumbnail.isValid && thumbnail.size.width <= 512, @"Large images use bounded thumbnails");
    [controller show:@"wallpapers"];
    check(controller.cards.count == 1 && controller.cards[0].preview != nil, @"Wallpaper thumbnails populate the gallery");
    check(controller.wallpaperSelector.segmentCount == 3 && [controller.wallpaperMode isEqual:[controller currentTheme][@"mode"]], @"Wallpaper assignment defaults to the current appearance, including fresh installs");
    rice_save_personal_preferences(directory, @{@"wallpapers":@{@"light":@"Sample.png", @"dark":@"Sample.png"}, @"followAppearance":@YES});
    controller.wallpaperSelector.selectedSegment = 1;
    [controller wallpaperModeChanged:controller.wallpaperSelector];
    check([controller.wallpaperMode isEqual:@"light"] && controller.cards[0].chosen &&
      [controller.cards[0].subtitle containsString:@"Light / Dark"], @"Light assignment highlights the saved image and labels its roles");
    controller.wallpaperSelector.selectedSegment = 2;
    [controller wallpaperModeChanged:controller.wallpaperSelector];
    check([controller.wallpaperMode isEqual:@"dark"] && controller.cards[0].chosen, @"Dark assignment is independently browsable without changing appearance");
    controller.testMode = @"light";
    [controller show:@"wallpapers"];
    check([controller.wallpaperMode isEqual:@"light"], @"Reopening in light mode does not reuse a stale dark assignment");
    controller.testMode = @"dark";
    [controller show:@"wallpapers"];
    check([controller.wallpaperMode isEqual:@"dark"], @"Reopening in dark mode targets the dark default");
    controller.testMode = nil;
    [controller applyWallpaper:[NSURL fileURLWithPath:@"/private/tmp/not-in-library.png"]];
    check([controller.galleryStatus.stringValue hasPrefix:@"Cannot open"], @"Out-of-library wallpapers cannot be applied");
    [controller show:@"terminal"];
    check(containsLabel(controller.root, @"Opacity and font size update live") && !containsLabel(controller.root, @"restart"),
      @"Terminal controls explain live updates without an obsolete restart warning");
    check(controller.sections.segmentCount == 4 && controller.sections.selectedSegment == 3 && !controller.cards.count,
      @"Terminal settings have a dedicated native customization section");
    check(controller.opacitySlider.continuous && controller.fontSizeSlider.continuous &&
      controller.opacitySlider.minValue == 0 && controller.opacitySlider.maxValue == 100 &&
      controller.fontSizeSlider.minValue == 8 && controller.fontSizeSlider.maxValue == 40,
      @"Native sliders expose valid, continuous opacity and font-size ranges");
    controller.opacitySlider.doubleValue = 83.3;
    [controller ghosttySliderChanged:controller.opacitySlider];
    NSTimer *pending = controller.ghosttyTimer;
    controller.fontSizeSlider.doubleValue = 18.7;
    [controller ghosttySliderChanged:controller.fontSizeSlider];
    check(controller.ghosttyTimer == pending && controller.ghosttyPending &&
      [controller.opacityValue.stringValue isEqual:@"83%"] && [controller.fontSizeValue.stringValue isEqual:@"18.5 pt"],
      @"Dragging updates labels immediately and coalesces writes into one timer");
    [controller show:@"themes"];
    NSDictionary *terminal = rice_ghostty_settings(directory);
    check(!controller.ghosttyPending && !controller.ghosttyTimer &&
      [terminal[@"opacity"] doubleValue] == .83 && [terminal[@"fontSize"] doubleValue] == 18.5,
      @"Leaving terminal settings flushes the last values without touching a live terminal");
    [controller show:@"terminal"];
    check(controller.opacitySlider.doubleValue == 83 && controller.fontSizeSlider.doubleValue == 18.5,
      @"Saved terminal slider values survive rebuilding the panel");
    [controller ghosttySliderChanged:controller.opacitySlider];
    check(!controller.ghosttyPending && !controller.ghosttyTimer, @"Unchanged slider values never queue a redundant reload");
    RiceTestController *shortPanel = [RiceTestController new];
    shortPanel.catalog = controller.catalog; shortPanel.page = @"terminal";
    shortPanel.root = [[RiceView alloc] initWithFrame:NSMakeRect(0, 0, 744, 400)];
    [shortPanel buildTerminal];
    for (NSView *view in shortPanel.root.subviews)
      check(NSContainsRect(shortPanel.root.bounds, view.frame), @"Short displays keep terminal controls in a bounded scroll view");
    NSString *logoPath = [rice_asset_directory(directory, @"logos") stringByAppendingPathComponent:@"Mark.svg"];
    [@"<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><circle cx='50' cy='50' r='35'/></svg>" writeToFile:logoPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    check(rice_asset_thumbnail([NSURL fileURLWithPath:logoPath]).isValid, @"SVG logos render natively");
    [controller show:@"logos"];
    check(controller.cards.count == 2 && controller.cards[0].chosen, @"Default and custom logos share one gallery");
    [controller chooseLogo:[NSURL fileURLWithPath:logoPath]];
    check([rice_personal_preferences(directory)[@"logo"] isEqual:@"Mark.svg"], @"Selected logo persists only in the private folder");
    NSArray *launcher = rice_launcher_arguments(directory, controller.catalog[0]);
    check([launcher containsObject:@"icon.drawing=off"], @"Custom logo replaces the launcher glyph");
    check([launcher containsObject:@"background.image.scale=0.5"] &&
      [launcher containsObject:@"background.image.padding_left=7"] &&
      [launcher containsObject:@"background.image.padding_right=7"] &&
      [launcher containsObject:@"background.image.y_offset=0"], @"24-point custom logos are centered in the 38-point launcher tile");
    for (NSString *argument in launcher) if ([argument hasPrefix:@"background.image="])
      check([[NSImage alloc] initWithContentsOfFile:[argument substringFromIndex:17]].isValid, @"Cached launcher image is valid");
    rice_save_personal_preferences(directory, @{@"logo":@"../outside.png", @"tintLogo":@YES});
    check([rice_personal_preferences(directory)[@"logo"] isEqual:@""], @"Personal selections reject path traversal");
    [controller show:@"logos"];
    controller.focusIndex = 20;
    [controller build:@"logos"];
    check(controller.focusIndex < (NSInteger)controller.cards.count, @"Refreshing a smaller library clamps keyboard focus");
    controller.refreshGeneration++;
    for (dispatch_source_t watcher in controller.assetWatchers) dispatch_source_cancel(watcher);
    controller.assetWatchers = nil;
    directory = originalDirectory;
    [NSFileManager.defaultManager removeItemAtPath:temporary error:NULL];
    [controller close];
    puts("PASS: native filters, keyboard navigation, active selection, layout and telemetry");
  }
  return 0;
}
