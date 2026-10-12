// GPL-3.0. Isolated files only; never applies a wallpaper or touches live Spaces.
#include "../appearance_wallpaper.h"

static void check(BOOL condition, NSString *message) {
  if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}

static void fixture(NSString *path, NSInteger width, NSInteger height, NSUInteger red, NSUInteger green, NSUInteger blue) {
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
    bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  NSUInteger pixel[] = {red, green, blue, 255};
  for (NSInteger y = 0; y < height; y++) for (NSInteger x = 0; x < width; x++) [bitmap setPixel:pixel atX:x y:y];
  check([[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES], @"Fixture writes");
}

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc != 2) return 2;
    NSString *config = [@(argv[1]) stringByAppendingPathComponent:@"sketchybar"];
    rice_prepare_assets(config);
    NSString *light = [rice_asset_directory(config, @"wallpapers") stringByAppendingPathComponent:@"Day + café.png"];
    NSString *dark = [rice_asset_directory(config, @"wallpapers") stringByAppendingPathComponent:@"Night.png"];
    fixture(light, 64, 32, 255, 128, 0); fixture(dark, 96, 64, 0, 64, 255);
    NSData *beforeLight = [NSData dataWithContentsOfFile:light], *beforeDark = [NSData dataWithContentsOfFile:dark];
    NSDictionary *names = @{@"light":light.lastPathComponent, @"dark":dark.lastPathComponent};
    NSError *error = nil;
    NSURL *pair = rice_wallpaper_pair(config, names, &error);
    check(pair != nil, error.localizedDescription ?: @"Pair encodes");
    check(rice_wallpaper_is_pair(pair), @"Apple appearance metadata decodes to light=0, dark=1");
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)pair, NULL);
    for (size_t i = 0; i < 2; i++) {
      CGImageRef image = CGImageSourceCreateImageAtIndex(source, i, NULL);
      check(CGImageGetWidth(image) == (i ? 96 : 64) && CGImageGetHeight(image) == (i ? 64 : 32), @"Each original keeps its dimensions; no upscaling");
      CGImageRelease(image);
    }
    CFRelease(source);
    check([[NSData dataWithContentsOfFile:light] isEqual:beforeLight] && [[NSData dataWithContentsOfFile:dark] isEqual:beforeDark], @"Originals are untouched");
    NSData *cached = [NSData dataWithContentsOfURL:pair];
    check([rice_wallpaper_pair(config, names, NULL) isEqual:pair] && [[NSData dataWithContentsOfURL:pair] isEqual:cached], @"Repeated selections reuse the encoded pair");
    check([rice_wallpaper_pair(config, @{@"light":light.lastPathComponent.decomposedStringWithCanonicalMapping,
      @"dark":dark.lastPathComponent}, NULL) isEqual:pair], @"macOS filename normalization does not lose accented wallpaper names");
    check(!rice_wallpaper_pair(config, @{@"light":@"../outside.png", @"dark":dark.lastPathComponent}, NULL), @"Traversal is rejected");
    NSString *symlink = [rice_asset_directory(config, @"wallpapers") stringByAppendingPathComponent:@"Link.png"];
    [NSFileManager.defaultManager createSymbolicLinkAtPath:symlink withDestinationPath:light error:NULL];
    check(!rice_wallpaper_pair(config, @{@"light":@"Link.png", @"dark":dark.lastPathComponent}, NULL), @"Symlinks do not escape the local library");
    NSDictionary *idle = @{@"Content":@{@"provider":@"user-screensaver"}};
    NSDictionary *store = @{@"AllSpacesAndDisplays":@"$null", @"Displays":@{@"display":@{@"Idle":idle}},
      @"Spaces":@{@"space-one":@{@"Default":@{@"Desktop":@{@"old":@YES}, @"Idle":idle}}},
      @"SystemDefault":@{@"Idle":idle}, @"futureSetting":@"preserve"};
    NSDictionary *next = rice_wallpaper_global_store(store, pair, &error);
    check(next && [store[@"AllSpacesAndDisplays"] isEqual:@"$null"], @"Global transformation does not mutate its input");
    check([rice_wallpaper_global_store(next, pair, NULL) isEqual:next], @"Selecting the existing wallpaper is a no-op, including timestamps and service refresh");
    for (NSString *key in @[@"Spaces", @"Displays", @"SystemDefault", @"futureSetting"])
      check([next[key] isEqual:store[key]], @"Per-Space, display, screensaver, and unrelated settings survive");
    check([next[@"AllSpacesAndDisplays"][@"Type"] isEqual:@"desktop"], @"Global desktop covers present and future Spaces without switching focus");
    NSDictionary *content = next[@"AllSpacesAndDisplays"][@"Desktop"][@"Content"];
    NSDictionary *configuration = [NSPropertyListSerialization propertyListWithData:content[@"Choices"][0][@"Configuration"] options:0 format:NULL error:NULL];
    check([configuration[@"url"][@"relative"] isEqual:pair.absoluteString], @"Native image URL uses proper escaping");
    NSDictionary *options = [NSPropertyListSerialization propertyListWithData:content[@"EncodedOptionValues"] options:0 format:NULL error:NULL];
    check([options[@"values"][@"placement"][@"picker"][@"id"] isEqual:@"Crop"] && !options[@"values"][@"appearanceMode"], @"Native crop and Automatic appearance are not pinned to light/dark");
    NSMutableDictionary *linked = [store mutableCopy];
    linked[@"AllSpacesAndDisplays"] = @{@"Type":@"linked", @"Linked":idle};
    NSDictionary *unlinked = rice_wallpaper_global_store(linked, pair, NULL)[@"AllSpacesAndDisplays"];
    check([unlinked[@"Idle"] isEqual:idle] && [unlinked[@"Type"] isEqual:@"individual"] && !unlinked[@"Linked"], @"A previously linked screensaver is preserved when changing only wallpaper");
    check(!rice_wallpaper_global_store(@{}, pair, NULL), @"Unknown native store formats fail closed");
    check(!rice_wallpaper_global_store(store, [NSURL URLWithString:@"https://example.com/remote.jpg"], NULL), @"Only local artwork can be applied");
    check(rice_save_personal_preferences(config, @{@"logo":@"Mark.svg", @"tintLogo":@YES, @"wallpapers":names, @"followAppearance":@YES}), @"Pair preferences save");
    NSDictionary *saved = rice_personal_preferences(config);
    check([saved[@"wallpapers"] isEqual:names] && [saved[@"followAppearance"] boolValue] && [saved[@"logo"] isEqual:@"Mark.svg"], @"Both wallpaper roles restore independently without losing the logo");
    rice_save_personal_preferences(config, @{@"wallpapers":@{@"dark":@"../outside.png", @"light":@".hidden.jpg"}, @"followAppearance":@"invalid"});
    check(![rice_personal_preferences(config)[@"wallpapers"] count] && ![rice_personal_preferences(config)[@"followAppearance"] boolValue], @"Malformed private choices are ignored");
    [NSFileManager.defaultManager removeItemAtPath:dark error:NULL];
    check(!rice_wallpaper_pair(config, names, NULL), @"A missing original never silently replaces the other appearance");
    puts("Wallpaper encoding, privacy, persistence, and all-Spaces regression checks passed.");
  }
}
