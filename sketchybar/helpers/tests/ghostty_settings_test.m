// Native persistence checks use only a disposable config tree, never Ghostty.
#include "../ghostty_settings.h"

static void check(BOOL result, NSString *message) {
  if (!result) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc != 2) return 2;
    NSString *root = @(argv[1]), *config = [root stringByAppendingPathComponent:@"sketchybar"];
    NSString *ghostty = [root stringByAppendingPathComponent:@"ghostty"];
    [NSFileManager.defaultManager createDirectoryAtPath:ghostty withIntermediateDirectories:YES attributes:nil error:NULL];
    NSDictionary *values = rice_ghostty_settings(config);
    check([values[@"opacity"] doubleValue] == .9 && [values[@"fontSize"] doubleValue] == 17, @"Fresh-install defaults");
    [@"# font-size = 99\nfont-size = 16.5\nbackground-opacity = 0.75\n" writeToFile:
      [ghostty stringByAppendingPathComponent:@"config.ghostty"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    values = rice_ghostty_settings(config);
    check([values[@"opacity"] doubleValue] == .75 && [values[@"fontSize"] doubleValue] == 16.5, @"Read existing defaults without changing them");
    NSError *error = nil;
    check(rice_ghostty_save_settings(config, .83, 18.5, &error) && !error, @"Save valid local settings");
    values = rice_ghostty_settings(config);
    check([values[@"opacity"] doubleValue] == .83 && [values[@"fontSize"] doubleValue] == 18.5, @"Private settings override shared defaults");
    NSString *path = rice_ghostty_settings_path(config);
    NSString *handwritten = @"# Keep this comment\ncursor-style = bar\nbackground-opacity = .5\nfont-size = 12\nfont-size = 13\n";
    [handwritten writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    check(rice_ghostty_save_settings(config, 1, 40, &error), @"Save at upper bounds");
    NSString *saved = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    check([saved containsString:@"# Keep this comment\ncursor-style = bar\n"] &&
      [[saved componentsSeparatedByString:@"font-size ="] count] == 2, @"Preserve unrelated lines and eliminate duplicate owned keys");
    NSDate *modified = [NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL][NSFileModificationDate];
    check(rice_ghostty_save_settings(config, 1, 40, &error) &&
      [modified isEqual:[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL][NSFileModificationDate]], @"Identical selection does not rewrite settings");
    for (NSArray *pair in @[@[@(-.1), @17], @[@1.1, @17], @[@.9, @7.5], @[@.9, @40.5], @[@(NAN), @17], @[@.9, @(INFINITY)]]) {
      check(!rice_ghostty_save_settings(config, [pair[0] doubleValue], [pair[1] doubleValue], &error), @"Invalid slider values are rejected");
      check([saved isEqual:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]], @"Rejected values leave the file untouched");
    }
    NSMutableDictionary *parsed = [@{@"opacity":@.9, @"fontSize":@17} mutableCopy];
    rice_ghostty_read_values(@"font-size = nan\nfont-size = 3.4oops\nfont-size = -1\nbackground-opacity = 2\n#background-opacity = .2\n", parsed);
    check([parsed isEqual:@{@"opacity":@.9, @"fontSize":@17}], @"Comments, non-numbers, partial numbers, and invalid ranges are ignored");
    check(rice_ghostty_save_settings(config, 0, 8, &error), @"Save at lower bounds");
    [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
    NSString *outside = [root stringByAppendingPathComponent:@"untouched.conf"];
    [@"untouched" writeToFile:outside atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [NSFileManager.defaultManager createSymbolicLinkAtPath:path withDestinationPath:outside error:NULL];
    check(!rice_ghostty_save_settings(config, .5, 12, &error) &&
      [[NSString stringWithContentsOfFile:outside encoding:NSUTF8StringEncoding error:NULL] isEqual:@"untouched"], @"Never follow a settings-file symlink for writes");
    puts("PASS: private Ghostty settings, validation, preservation, and idempotence");
  }
  return 0;
}
