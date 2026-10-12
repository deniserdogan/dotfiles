// GPL-3.0. Private, user-owned artwork. No personal assets ship in the repo.
#pragma once
#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>
#include "theme_catalog.h"
#include "theme_preview.h"

static inline NSString *rice_personal_directory(NSString *config) {
  return [[config stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"rice"];
}

static inline NSString *rice_asset_directory(NSString *config, NSString *kind) {
  return [rice_personal_directory(config) stringByAppendingPathComponent:kind];
}

static inline void rice_prepare_assets(NSString *config) {
  for (NSString *kind in @[@"wallpapers", @"logos", @"cache"])
    [NSFileManager.defaultManager createDirectoryAtPath:rice_asset_directory(config, kind) withIntermediateDirectories:YES attributes:nil error:NULL];
}

static inline NSMutableDictionary *rice_personal_preferences(NSString *config) {
  id saved = rice_json_file([rice_personal_directory(config) stringByAppendingPathComponent:@"personalization.json"]);
  NSMutableDictionary *preferences = [@{@"logo":@"", @"tintLogo":@YES, @"wallpapers":@{}, @"followAppearance":@NO} mutableCopy];
  if ([saved isKindOfClass:NSDictionary.class]) {
    NSString *logo = saved[@"logo"];
    if ([logo isKindOfClass:NSString.class] && [logo.lastPathComponent isEqual:logo] && ![logo hasPrefix:@"."])
      preferences[@"logo"] = logo;
    if ([saved[@"tintLogo"] isKindOfClass:NSNumber.class]) preferences[@"tintLogo"] = saved[@"tintLogo"];
    if ([saved[@"followAppearance"] isKindOfClass:NSNumber.class]) preferences[@"followAppearance"] = saved[@"followAppearance"];
    NSMutableDictionary *wallpapers = [NSMutableDictionary dictionary];
    if ([saved[@"wallpapers"] isKindOfClass:NSDictionary.class]) {
      for (NSString *mode in @[@"dark", @"light"]) {
        NSString *name = saved[@"wallpapers"][mode];
        if ([name isKindOfClass:NSString.class] && name.length &&
            [name.lastPathComponent isEqual:name] && ![name hasPrefix:@"."])
          wallpapers[mode] = name;
      }
    }
    preferences[@"wallpapers"] = wallpapers;
  }
  return preferences;
}

static inline BOOL rice_save_personal_preferences(NSString *config, NSDictionary *preferences) {
  rice_prepare_assets(config);
  NSData *data = [NSJSONSerialization dataWithJSONObject:preferences options:NSJSONWritingSortedKeys error:NULL];
  return [data writeToFile:[rice_personal_directory(config) stringByAppendingPathComponent:@"personalization.json"] atomically:YES];
}

static inline NSArray<NSURL *> *rice_asset_files(NSString *config, NSString *kind) {
  NSSet *extensions = [NSSet setWithArray:[kind isEqual:@"logos"] ?
    @[@"png", @"svg", @"pdf", @"jpg", @"jpeg", @"heic", @"webp"] :
    @[@"jpg", @"jpeg", @"png", @"heic", @"heif", @"tif", @"tiff", @"webp", @"avif", @"bmp"]];
  NSURL *folder = [NSURL fileURLWithPath:rice_asset_directory(config, kind) isDirectory:YES];
  NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folder includingPropertiesForKeys:
    @[NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey, NSURLContentModificationDateKey, NSURLFileSizeKey]
    options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
  NSMutableArray *images = [NSMutableArray array];
  for (NSURL *url in files) {
    NSNumber *regular = nil, *link = nil;
    [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:NULL];
    [url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:NULL];
    if (regular.boolValue && !link.boolValue && [extensions containsObject:url.pathExtension.lowercaseString]) [images addObject:url];
  }
  return [images sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
    return [a.lastPathComponent localizedStandardCompare:b.lastPathComponent];
  }];
}

static inline NSString *rice_asset_cache_key(NSURL *url) {
  NSDate *modified = nil; NSNumber *size = nil;
  [url getResourceValue:&modified forKey:NSURLContentModificationDateKey error:NULL];
  [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
  return [NSString stringWithFormat:@"%@:%.9f:%@", url.path, modified.timeIntervalSince1970, size];
}

static inline NSImage *rice_asset_thumbnail(NSURL *url) {
  static NSCache *cache;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ cache = [NSCache new]; cache.countLimit = 96; cache.totalCostLimit = 32 * 1024 * 1024; });
  NSString *key = rice_asset_cache_key(url);
  NSImage *image = [cache objectForKey:key];
  if (image) return image;
  CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
  if (source) {
    NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
      (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,
      (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@512};
    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    if (thumbnail) { image = [[NSImage alloc] initWithCGImage:thumbnail size:NSZeroSize]; CGImageRelease(thumbnail); }
    CFRelease(source);
  }
  if (!image && [@[@"svg", @"pdf"] containsObject:url.pathExtension.lowercaseString]) {
    image = [[NSImage alloc] initWithContentsOfURL:url];
  }
  if (image.isValid) { [cache setObject:image forKey:key cost:512 * 512 * 4]; return image; }
  return nil;
}

static inline void rice_draw_fitted_image(NSImage *image, NSRect rect, BOOL fill) {
  if (image.size.width <= 0 || image.size.height <= 0) return;
  CGFloat x = rect.size.width / image.size.width, y = rect.size.height / image.size.height;
  CGFloat scale = fill ? MAX(x, y) : MIN(x, y);
  NSSize size = NSMakeSize(image.size.width * scale, image.size.height * scale);
  NSRect target = NSMakeRect(NSMidX(rect)-size.width/2, NSMidY(rect)-size.height/2, size.width, size.height);
  [image drawInRect:target fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}

static inline NSArray<NSString *> *rice_launcher_arguments(NSString *config, NSDictionary *theme) {
  NSDictionary *preferences = rice_personal_preferences(config);
  NSString *name = preferences[@"logo"];
  NSURL *source = nil;
  for (NSURL *url in rice_asset_files(config, @"logos")) if ([url.lastPathComponent isEqual:name]) { source = url; break; }
  NSImage *image = source ? rice_asset_thumbnail(source) : nil;
  if (!image) return @[@"--set", @"apple", @"icon.drawing=on", @"background.image.drawing=off"];
  BOOL tint = [preferences[@"tintLogo"] boolValue];
  NSString *identity = [NSString stringWithFormat:@"%@:%@:%d", rice_asset_cache_key(source), theme[@"colors"][@"mauve"], tint];
  NSString *path = [rice_asset_directory(config, @"cache") stringByAppendingPathComponent:
    [NSString stringWithFormat:@"launcher-%lx.png", (unsigned long)identity.hash]];
  if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:48 pixelsHigh:48
      bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    rice_draw_fitted_image(image, NSMakeRect(2, 2, 44, 44), NO);
    if (tint) { [rice_rgb(theme[@"colors"][@"mauve"]) setFill]; NSRectFillUsingOperation(NSMakeRect(0, 0, 48, 48), NSCompositingOperationSourceIn); }
    [NSGraphicsContext restoreGraphicsState];
    if (![[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES]) return nil;
  }
  return @[@"--set", @"apple", @"icon.drawing=off", [@"background.image=" stringByAppendingString:path],
    // SketchyBar anchors background images to the item's left edge. Center
    // the 24-point image inside the existing 38-point launcher hit target.
    @"background.image.drawing=on", @"background.image.scale=0.5",
    @"background.image.padding_left=7", @"background.image.padding_right=7", @"background.image.y_offset=0"];
}
