// GPL-3.0. Explicit wallpaper commands; no background polling or theme hooks.
#include "appearance_wallpaper.h"

int main(int argc, char **argv) {
  @autoreleasepool {
    NSString *config = getenv("CONFIG_DIR") ? @(getenv("CONFIG_DIR")) : [NSHomeDirectory() stringByAppendingPathComponent:@".config/sketchybar"];
    if (argc == 3 && !strcmp(argv[1], "--inspect")) {
      NSURL *url = [NSURL fileURLWithPath:@(argv[2])];
      CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
      if (!source) return 1;
      NSMutableArray *frames = [NSMutableArray array];
      for (size_t i = 0; i < CGImageSourceGetCount(source); i++) {
        NSDictionary *p = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, i, NULL));
        [frames addObject:@{@"width":p[(__bridge NSString *)kCGImagePropertyPixelWidth] ?: @0,
          @"height":p[(__bridge NSString *)kCGImagePropertyPixelHeight] ?: @0}];
      }
      NSDictionary *value = @{@"frames":frames, @"appearance":rice_wallpaper_appearance(source) ?: @{}};
      CFRelease(source);
      NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:NULL];
      fwrite(data.bytes, 1, data.length, stdout); return 0;
    }
    if (argc != 4 || (strcmp(argv[1], "--build-pair") && strcmp(argv[1], "--pair"))) return 2;
    NSError *error = nil;
    NSDictionary *names = @{@"dark":@(argv[2]), @"light":@(argv[3])};
    NSURL *url = rice_wallpaper_pair(config, names, &error);
    if (url && !strcmp(argv[1], "--pair")) {
      if (!rice_wallpaper_apply_all_spaces(config, url, &error)) url = nil;
      else {
        NSMutableDictionary *preferences = rice_personal_preferences(config);
        preferences[@"wallpapers"] = names; preferences[@"followAppearance"] = @YES;
        if (!rice_save_personal_preferences(config, preferences)) {
          rice_wallpaper_error(&error, @"Could not save wallpaper choices."); url = nil;
        }
      }
    }
    if (!url) { fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1; }
    printf("%s\n", url.path.fileSystemRepresentation); return 0;
  }
}
