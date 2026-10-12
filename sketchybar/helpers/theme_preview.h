// GPL-3.0. Code-rendered representative previews: no screen recording or user data.
#pragma once
#import <AppKit/AppKit.h>
#include "theme_catalog.h"

static inline NSColor *rice_rgb(NSString *hex) {
  unsigned rgb = (unsigned)strtoul(hex.UTF8String, NULL, 16);
  return [NSColor colorWithSRGBRed:((rgb >> 16) & 255) / 255.0 green:((rgb >> 8) & 255) / 255.0 blue:(rgb & 255) / 255.0 alpha:1];
}

static inline void rice_fill(NSRect rect, CGFloat radius, NSColor *color) {
  [color setFill]; [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius] fill];
}

static inline void rice_text(NSString *text, NSRect rect, CGFloat size, NSFontWeight weight, NSColor *color, BOOL mono) {
  NSFont *font = mono ? [NSFont monospacedSystemFontOfSize:size weight:weight] : [NSFont systemFontOfSize:size weight:weight];
  NSMutableDictionary *attributes = [@{NSForegroundColorAttributeName:color ?: NSColor.textColor} mutableCopy];
  if (font) attributes[NSFontAttributeName] = font;
  [text drawInRect:rect withAttributes:attributes];
}

static inline NSImage *rice_theme_preview(NSDictionary *theme) {
  static NSMutableDictionary *cache;
  if (!cache) cache = [NSMutableDictionary dictionary];
  if (cache[theme[@"id"]]) return cache[theme[@"id"]];
  NSDictionary *c = theme[@"colors"];
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:720 pixelsHigh:400
    bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
  NSRect bounds = NSMakeRect(0, 0, 720, 400);
    NSColor *base = rice_rgb(c[@"background"]), *surface = rice_rgb(c[@"surface"]), *fg = rice_rgb(c[@"foreground"]);
    NSColor *accent = rice_rgb(c[@"blue"]), *teal = rice_rgb(c[@"teal"]), *green = rice_rgb(c[@"green"]), *purple = rice_rgb(c[@"mauve"]);
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[base blendedColorWithFraction:.22 ofColor:accent] endingColor:base];
    [gradient drawInRect:bounds angle:-30];
    rice_fill(NSMakeRect(380, -110, 480, 480), 240, [teal colorWithAlphaComponent:.09]);
    rice_fill(NSMakeRect(-140, 140, 420, 420), 210, [purple colorWithAlphaComponent:.09]);
    rice_fill(NSMakeRect(14, 359, 692, 29), 9, [surface colorWithAlphaComponent:.95]);
    rice_text(@"", NSMakeRect(28, 365, 20, 17), 13, NSFontWeightSemibold, purple, NO);
    rice_fill(NSMakeRect(56, 363, 48, 21), 6, accent);
    rice_text(@"1  ▣", NSMakeRect(64, 367, 40, 13), 10, NSFontWeightSemibold, base, YES);
    rice_text(@"2  ◉    3  ◇    Ghostty", NSMakeRect(115, 367, 245, 13), 10, NSFontWeightMedium, fg, YES);
    rice_text(@"CPU 12%     86%     10:24", NSMakeRect(500, 367, 195, 13), 10, NSFontWeightMedium, fg, YES);
    rice_fill(NSMakeRect(24, 35, 425, 308), 11, [base colorWithAlphaComponent:.96]);
    rice_fill(NSMakeRect(24, 316, 425, 27), 11, surface);
    for (int i = 0; i < 3; i++) rice_fill(NSMakeRect(36+i*15, 326, 7, 7), 3.5, [fg colorWithAlphaComponent:.3]);
    rice_text(@"app.py", NSMakeRect(190, 322, 120, 16), 11, NSFontWeightMedium, fg, NO);
    NSArray *lines = @[@[@"from fastapi import FastAPI", purple], @[@"", fg], @[@"app = FastAPI()", fg],
      @[@"", fg], @[@"@app.get(\"/hello\")", accent], @[@"async def hello():", purple],
      @[@"    return {\"message\": \"Hello, world\"}", green], @[@"", fg], @[@"# Make yourself at home.", [fg colorWithAlphaComponent:.45]]];
    for (NSUInteger i = 0; i < lines.count; i++) {
      rice_text([NSString stringWithFormat:@"%2lu", i+1], NSMakeRect(37, 286-i*23, 26, 20), 12, NSFontWeightRegular, [fg colorWithAlphaComponent:.35], YES);
      rice_text(lines[i][0], NSMakeRect(75, 286-i*23, 370, 20), 13, NSFontWeightRegular, lines[i][1], YES);
    }
    rice_fill(NSMakeRect(24, 35, 425, 21), 5, surface);
    rice_text(@" NORMAL    app.py                 Python", NSMakeRect(32, 40, 405, 14), 10, NSFontWeightMedium, accent, YES);
    rice_fill(NSMakeRect(463, 188, 233, 155), 11, surface);
    rice_text(@"System health", NSMakeRect(481, 309, 190, 20), 14, NSFontWeightSemibold, fg, NO);
    rice_text(@"CPU        12%", NSMakeRect(481, 278, 190, 20), 13, NSFontWeightRegular, fg, YES);
    NSBezierPath *graph = [NSBezierPath bezierPath];
    [graph moveToPoint:NSMakePoint(481, 218)];
    for (int i = 0; i < 22; i++) [graph lineToPoint:NSMakePoint(481+i*9.1, 221+(i*17 % 37))];
    graph.lineWidth = 2; [green setStroke]; [graph stroke];
    rice_fill(NSMakeRect(463, 35, 233, 139), 11, [base colorWithAlphaComponent:.96]);
    rice_text(@"~/projects", NSMakeRect(481, 141, 190, 20), 14, NSFontWeightSemibold, fg, YES);
    rice_text(@"❯ git status", NSMakeRect(481, 109, 190, 20), 13, NSFontWeightRegular, accent, YES);
    rice_text(@"On branch main", NSMakeRect(481, 85, 190, 20), 12, NSFontWeightRegular, fg, YES);
    rice_text(@"Working tree clean", NSMakeRect(481, 61, 190, 20), 12, NSFontWeightRegular, green, YES);
  [NSGraphicsContext restoreGraphicsState];
  // Store pixels, not a lazy drawing handler: appearance changes and hovering
  // must never rerun AppKit font/layout work for an existing preview.
  NSImage *image = [[NSImage alloc] initWithSize:bounds.size];
  [image addRepresentation:bitmap];
  cache[theme[@"id"]] = image;
  return image;
}
