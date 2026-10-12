// GPL-3.0. Isolated preference tests. Never changes the system appearance.
#include "../theme_catalog.h"

static void check(BOOL condition, NSString *message) {
  if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc != 3) return 2;
    NSArray *catalog = rice_themes(@(argv[1]));
    check(catalog != nil, @"Catalog loads");
    NSString *fixture = @(argv[2]);
    NSString *directory = [fixture stringByAppendingPathComponent:@"sketchybar"];
    NSMutableDictionary *selection = rice_theme_selection(directory, catalog);
    check([selection isEqual:@{@"dark":@"nordfox", @"light":@"xcode-light"}], @"First-run defaults");

    check(rice_remember_theme(directory, catalog, selection, @"kanagawa"), @"Pick a dark theme");
    check([selection[@"light"] isEqual:@"xcode-light"], @"Dark choice preserves light choice");
    check(rice_remember_theme(directory, catalog, selection, @"everforest-light"), @"Pick a light theme");
    selection = rice_theme_selection(directory, catalog); // New process/restart reads disk.
    check([selection isEqual:@{@"dark":@"kanagawa", @"light":@"everforest-light"}], @"Both appearances restore after restart");
    check(rice_remember_theme(directory, catalog, selection, @"carbonfox"), @"Replace only the last dark choice");
    selection = rice_theme_selection(directory, catalog);
    check([selection isEqual:@{@"dark":@"carbonfox", @"light":@"everforest-light"}], @"Last choice wins independently per appearance");
    check([rice_theme(catalog, selection[@"dark"])[@"mode"] isEqual:@"dark"] &&
      [rice_theme(catalog, selection[@"light"])[@"mode"] isEqual:@"light"], @"Appearance switches resolve the correct saved theme");

    NSData *saved = [NSData dataWithContentsOfFile:rice_selection_path(directory)];
    NSDictionary *before = [selection copy];
    check(!rice_remember_theme(directory, catalog, selection, @"unknown-theme"), @"Reject missing themes");
    check([selection isEqual:before] && [[NSData dataWithContentsOfFile:rice_selection_path(directory)] isEqual:saved], @"Invalid choices leave memory and disk unchanged");
    NSString *blocked = [fixture stringByAppendingPathComponent:@"blocked"];
    [@"Not a directory" writeToFile:blocked atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    check(!rice_remember_theme([blocked stringByAppendingPathComponent:@"sketchybar"], catalog, selection, @"tokyo-night"), @"Report preference write failures");
    check([selection isEqual:before], @"Failed writes preserve in-memory preferences");

    // Existing legacy choices migrate without changing the other appearance.
    NSString *legacy = [fixture stringByAppendingPathComponent:@"legacy/sketchybar"];
    NSString *legacyPath = [legacy stringByAppendingPathComponent:@"themes/selection.json"];
    [NSFileManager.defaultManager createDirectoryAtPath:legacyPath.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"{\"dark\":\"rose-pine\",\"light\":\"dayfox\"}" writeToFile:legacyPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSMutableDictionary *migrated = rice_theme_selection(legacy, catalog);
    check([migrated isEqual:@{@"dark":@"rose-pine", @"light":@"dayfox"}], @"Load legacy saved pair");
    check(rice_remember_theme(legacy, catalog, migrated, @"github-light"), @"Save in the private preference location");
    check([rice_theme_selection(legacy, catalog) isEqual:@{@"dark":@"rose-pine", @"light":@"github-light"}], @"New private preferences take precedence over legacy choices");

    [@"{\"dark\":\"github-light\",\"light\":\"missing\"}" writeToFile:rice_selection_path(directory)
      atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    check([rice_theme_selection(directory, catalog) isEqual:@{@"dark":@"nordfox", @"light":@"xcode-light"}], @"Removed and wrong-mode choices fall back safely");
    puts("PASS: independent theme memory, restart restoration, legacy migration and write failures");
  }
  return 0;
}
