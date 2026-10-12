// GPL-3.0. Two private Ghostty overrides; no terminal restarts or UI scripting.
#pragma once
#import <Foundation/Foundation.h>
#include <libproc.h>
#include <signal.h>
#include <math.h>

static inline NSString *rice_ghostty_settings_path(NSString *config) {
  return [[config stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"rice/ghostty.conf"];
}

static inline BOOL rice_ghostty_number(NSString *text, double *value) {
  NSScanner *scanner = [NSScanner scannerWithString:text];
  scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  double number;
  if (![scanner scanDouble:&number] || !scanner.isAtEnd || !isfinite(number)) return NO;
  *value = number; return YES;
}

static inline void rice_ghostty_read_values(NSString *text, NSMutableDictionary *values) {
  for (NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
    NSRange equals = [line rangeOfString:@"="];
    if (equals.location == NSNotFound) continue;
    NSString *key = [[line substringToIndex:equals.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSString *raw = [[line substringFromIndex:NSMaxRange(equals)] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    double value;
    if (!rice_ghostty_number(raw, &value)) continue;
    if ([key isEqual:@"background-opacity"] && value >= 0 && value <= 1) values[@"opacity"] = @(value);
    if ([key isEqual:@"font-size"] && value >= 8 && value <= 40) values[@"fontSize"] = @(value);
  }
}

static inline NSDictionary *rice_ghostty_settings(NSString *config) {
  NSMutableDictionary *values = [@{@"opacity":@0.9, @"fontSize":@17} mutableCopy];
  NSString *root = [config stringByDeletingLastPathComponent];
  // Ghostty reads the legacy config after config.ghostty when both exist.
  for (NSString *path in @[[root stringByAppendingPathComponent:@"ghostty/config.ghostty"],
      [root stringByAppendingPathComponent:@"ghostty/config"], rice_ghostty_settings_path(config)])
    rice_ghostty_read_values([NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] ?: @"", values);
  return values;
}

static inline BOOL rice_ghostty_save_settings(NSString *config, double opacity, double fontSize, NSError **error) {
  if (!isfinite(opacity) || opacity < 0 || opacity > 1 || !isfinite(fontSize) || fontSize < 8 || fontSize > 40) {
    if (error) *error = [NSError errorWithDomain:@"com.denis.rice.ghostty" code:1
      userInfo:@{NSLocalizedDescriptionKey:@"Opacity must be 0–100% and font size 8–40 pt."}];
    return NO;
  }
  NSString *path = rice_ghostty_settings_path(config);
  NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];
  if (attributes && ![attributes[NSFileType] isEqual:NSFileTypeRegular]) {
    if (error) *error = [NSError errorWithDomain:@"com.denis.rice.ghostty" code:2
      userInfo:@{NSLocalizedDescriptionKey:@"The private Ghostty settings must be a regular file."}];
    return NO;
  }
  NSString *previous = attributes ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error] : nil;
  if (attributes && !previous) return NO;
  NSMutableArray *lines = [NSMutableArray array];
  if (!previous) [lines addObject:@"# Local terminal appearance, managed by Rice customization."];
  // Preserve comments and any unrelated hand-written settings.
  for (NSString *line in [previous componentsSeparatedByString:@"\n"]) {
    NSString *key = [[[line componentsSeparatedByString:@"="] firstObject] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (![key isEqual:@"font-size"] && ![key isEqual:@"background-opacity"]) [lines addObject:line];
  }
  while ([lines.lastObject isEqual:@""]) [lines removeLastObject];
  [lines addObject:[NSString stringWithFormat:@"background-opacity = %.2f", opacity]];
  [lines addObject:[NSString stringWithFormat:@"font-size = %.1f", fontSize]];
  NSString *next = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
  if ([next isEqual:previous]) return YES;
  if (![NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES attributes:nil error:error]) return NO;
  return [next writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

static inline BOOL rice_ghostty_reload(void) {
  int capacity = proc_listallpids(NULL, 0) + 128;
  if (capacity <= 128) return NO;
  pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
  if (!pids) return NO;
  int count = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
  BOOL reloaded = NO;
  for (int i = 0; i < count; i++) {
    char name[64] = {0}; struct proc_bsdinfo info = {0};
    if (pids[i] > 1 && proc_name(pids[i], name, sizeof(name)) > 0 && !strcmp(name, "ghostty") &&
        proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &info, sizeof(info)) == sizeof(info) && info.pbi_uid == getuid())
      reloaded |= kill(pids[i], SIGUSR2) == 0;
  }
  free(pids); return reloaded;
}
