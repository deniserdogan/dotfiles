// GPL-3.0. Documentation artwork from the real AppKit views, not a UI mockup.
// No application delegate, IPC, screen capture or live telemetry.
// The desktop plate uses only the explicitly supplied documentation capture.
#define main rice_panel_application_main
#include "../../sketchybar/helpers/native_panel.m"
#undef main

@interface DocsBackdrop : NSView
@end
@implementation DocsBackdrop
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
  (void)dirty;
  rice_fill(self.bounds, 20, NSColor.windowBackgroundColor);
}
@end

@interface DocsController : RiceController
@property(copy) NSString *themeID;
@end
@implementation DocsController
- (NSDictionary *)currentTheme { return rice_theme(self.catalog, self.themeID); }
- (NSTextField *)label:(NSString *)text frame:(NSRect)frame size:(CGFloat)size weight:(NSFontWeight)weight secondary:(BOOL)secondary {
  if ([self.page isEqual:@"control"] && frame.origin.y == 23) text = @"YOUR DESKTOP";
  if ([self.page isEqual:@"control"] && frame.origin.y == 80) text = @"MacBook Air";
  return [super label:text frame:frame size:size weight:weight secondary:secondary];
}
- (void)updateStatus {
  NSDictionary *sample = @{@"cpu":@"12%", @"load":@"Load 1.24 · 1 min",
    @"memory":@"48%", @"memoryDetail":@"7.7 / 16 GB", @"battery":@"86%",
    @"powerDetail":@"On battery", @"storage":@"Storage  ·  256 GB free of 512 GB",
    @"displays":@"1 display · Built-in Retina Display", @"vpn":@"No VPN tunnel or system proxy detected"};
  for (NSString *key in sample) self.labels[key].stringValue = sample[key];
  self.storage.doubleValue = .5;
}
- (void)build:(NSString *)page {
  [super build:page];
  // A screen's vibrancy backdrop cannot be reproduced offscreen. Use the
  // matching native opaque surface, leaving every control and its layout intact.
  NSView *glass = self.root.subviews.firstObject;
  if ([glass isKindOfClass:NSVisualEffectView.class]) [glass removeFromSuperview];
  DocsBackdrop *backdrop = [[DocsBackdrop alloc] initWithFrame:self.root.bounds];
  [self.root addSubview:backdrop positioned:NSWindowBelow relativeTo:nil];
}
@end

static NSImage *panel(NSArray *catalog, NSString *theme, NSString *page, NSInteger filter) {
  if (!rice_theme(catalog, theme)) { fprintf(stderr, "Unknown theme: %s\n", theme.UTF8String); exit(1); }
  DocsController *controller = [DocsController new];
  controller.catalog = catalog; controller.themeID = theme;
  controller.snapshot = YES; controller.filterIndex = filter;
  [controller show:page];
  [controller.root layoutSubtreeIfNeeded];
  NSSize size = controller.root.bounds.size;
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
    pixelsWide:size.width*2 pixelsHigh:size.height*2 bitsPerSample:8 samplesPerPixel:4
    hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  rep.size = size;
  [controller.root cacheDisplayInRect:controller.root.bounds toBitmapImageRep:rep];
  NSImage *image = [[NSImage alloc] initWithSize:controller.root.bounds.size];
  [image addRepresentation:rep];
  [controller close];
  return image;
}

static void text(NSString *value, NSRect rect, CGFloat size, NSFontWeight weight, NSString *hex) {
  rice_text(value, rect, size, weight, rice_rgb(hex), NO);
}

static void artwork(NSImage *image, NSRect rect, BOOL light) {
  [NSGraphicsContext saveGraphicsState];
  NSShadow *shadow = [NSShadow new];
  shadow.shadowColor = [NSColor.blackColor colorWithAlphaComponent:light ? .15 : .4];
  shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSMakeSize(0, 10); [shadow set];
  rice_fill(rect, 20, light ? rice_rgb(@"f3f3f5") : rice_rgb(@"252528"));
  [NSGraphicsContext restoreGraphicsState];
  [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
  NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, .5, .5) xRadius:20 yRadius:20];
  [[NSColor.whiteColor colorWithAlphaComponent:light ? .8 : .12] setStroke]; outline.lineWidth = 1; [outline stroke];
}

static BOOL plate(NSString *path, NSSize size, BOOL light, void (^draw)(void)) {
  NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
    pixelsWide:size.width*2 pixelsHigh:size.height*2 bitsPerSample:8 samplesPerPixel:4
    hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
  CGContextRef cg = context.CGContext;
  CGContextTranslateCTM(cg, 0, size.height*2); CGContextScaleCTM(cg, 2, -2);
  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES]];
  NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:rice_rgb(light ? @"f8f7f3" : @"111621")
    endingColor:rice_rgb(light ? @"e6edf5" : @"222d45")];
  [gradient drawInRect:NSMakeRect(0, 0, size.width, size.height) angle:30];
  draw();
  [NSGraphicsContext restoreGraphicsState];
  return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

static BOOL desktop_plate(NSString *source, NSString *output) {
  NSImage *image = [[NSImage alloc] initWithContentsOfFile:source];
  if (!image.isValid) { fputs("Missing or invalid documentation desktop capture\n", stderr); return NO; }
  NSImageRep *pixels = image.representations.firstObject;
  CGFloat width = pixels.pixelsWide / 2.0, height = pixels.pixelsHigh / 2.0;
  if (width <= 0 || height <= 0) return NO;
  // The 2x plate uses the original capture at 1:1 pixel resolution. No crop,
  // font substitution, retouching or synthesized editor/browser content.
  return plate(output, NSMakeSize(width+112, height+246), NO, ^{
    text(@"THE DESKTOP / NEOVIM", NSMakeRect(56, 30, width, 20), 11, NSFontWeightSemibold, @"9aabc6");
    text(@"Built around your workflow.", NSMakeRect(54, 62, width, 65), 46, NSFontWeightBold, @"f4f6fb");
    text(@"SketchyBar · Ghostty · Neovim", NSMakeRect(56, 132, width, 28), 18, NSFontWeightRegular, @"b5c1d7");
    NSRect rect = NSMakeRect(56, 190, width, height);
    // Reuse the same native shadow and frame as the panel showcases.
    artwork(nil, rect, NO);
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:20 yRadius:20] addClip];
    [NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationNone;
    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
    NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, .5, .5) xRadius:20 yRadius:20];
    [[NSColor.whiteColor colorWithAlphaComponent:.12] setStroke]; outline.lineWidth = 1; [outline stroke];
    text(@"Actual desktop capture · Explorer, Python LSP & completion", NSMakeRect(56, height+207, width, 20), 11, NSFontWeightRegular, @"9aabc6");
  });
}

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc != 3) { fputs("Usage: render <checkout> <output-directory>\n", stderr); return 2; }
    directory = [@(argv[1]) stringByAppendingPathComponent:@"sketchybar"];
    NSArray *catalog = rice_themes(directory);
    if (!catalog) return 1;
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    // Do not set an application delegate or run the application event loop.
    NSImage *darkGallery = panel(catalog, @"tokyo-night", @"themes", 0);
    NSImage *darkControl = panel(catalog, @"tokyo-night", @"control", 0);
    NSImage *lightGallery = panel(catalog, @"catppuccin-latte", @"themes", 2);
    NSString *output = @(argv[2]);
    BOOL ok = desktop_plate([@(argv[1]) stringByAppendingPathComponent:@"docs/media/desktop-source.png"],
      [output stringByAppendingPathComponent:@"desktop.png"]);
    ok &= plate([output stringByAppendingPathComponent:@"overview.png"], NSMakeSize(1400, 1040), NO, ^{
      text(@"DOTFILES / MACOS", NSMakeRect(64, 45, 600, 20), 12, NSFontWeightSemibold, @"9aabc6");
      text(@"Make room for your workflow.", NSMakeRect(62, 84, 1260, 68), 48, NSFontWeightBold, @"f4f6fb");
      text(@"Keyboard-first tiling. Coordinated themes. Native desktop controls.", NSMakeRect(64, 163, 1260, 30), 19, NSFontWeightRegular, @"b5c1d7");
      artwork(darkGallery, NSMakeRect(64, 236, 744, 694), NO);
      artwork(darkControl, NSMakeRect(886, 236, 420, 664), NO);
      text(@"18 THEMES  /  10 LIGHT  /  8 DARK", NSMakeRect(64, 966, 600, 22), 12, NSFontWeightSemibold, @"b5c1d7");
      text(@"Actual AppKit views · Sample system data", NSMakeRect(886, 966, 440, 22), 11, NSFontWeightRegular, @"9aabc6");
    });
    ok &= plate([output stringByAppendingPathComponent:@"themes-light.png"], NSMakeSize(1100, 940), YES, ^{
      text(@"LIGHT IS A FIRST-CLASS CITIZEN", NSMakeRect(64, 42, 970, 20), 11, NSFontWeightSemibold, @"68758d");
      text(@"Find your palette.", NSMakeRect(62, 74, 980, 60), 42, NSFontWeightBold, @"242d40");
      text(@"Ten light themes, with previews before you commit.", NSMakeRect(64, 141, 980, 28), 17, NSFontWeightRegular, @"647089");
      artwork(lightGallery, NSMakeRect(178, 200, 744, 694), YES);
      text(@"Actual AppKit view · Palette previews are illustrative", NSMakeRect(178, 910, 744, 20), 10, NSFontWeightRegular, @"68758d");
    });
    ok &= plate([output stringByAppendingPathComponent:@"control-center.png"], NSMakeSize(1100, 820), NO, ^{
      text(@"NATIVE CONTROL CENTER", NSMakeRect(64, 102, 470, 20), 11, NSFontWeightSemibold, @"9aabc6");
      text(@"Less hunting.\nMore doing.", NSMakeRect(60, 142, 500, 124), 46, NSFontWeightBold, @"f4f6fb");
      text(@"A clear view of your Mac,\none click from the bar.", NSMakeRect(64, 301, 460, 65), 21, NSFontWeightRegular, @"b5c1d7");
      text(@"01   CPU, memory, battery & storage", NSMakeRect(64, 430, 480, 28), 16, NSFontWeightMedium, @"d4dced");
      text(@"02   Display & connection status", NSMakeRect(64, 479, 480, 28), 16, NSFontWeightMedium, @"d4dced");
      text(@"03   Settings, apps & personalization", NSMakeRect(64, 528, 480, 28), 16, NSFontWeightMedium, @"d4dced");
      text(@"Built with AppKit. Not a web overlay.", NSMakeRect(64, 670, 480, 25), 13, NSFontWeightMedium, @"9aabc6");
      artwork(darkControl, NSMakeRect(616, 66, 420, 664), NO);
      text(@"Actual AppKit view · Sample system data", NSMakeRect(616, 755, 440, 22), 11, NSFontWeightRegular, @"9aabc6");
    });
    if (!ok) return 1;
    puts("Rendered desktop.png from the supplied capture; panel showcases use public sample data.");
  }
  return 0;
}
