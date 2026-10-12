// GPL-3.0. A two-frame HEIC lets macOS own appearance transitions, even offline.
#pragma once
#include "personal_assets.h"
#include <CommonCrypto/CommonDigest.h>
#include <libproc.h>
#include <signal.h>

static inline BOOL rice_wallpaper_error(NSError **error, NSString *message) {
  if (error) *error = [NSError errorWithDomain:@"com.denis.rice.wallpaper" code:1
    userInfo:@{NSLocalizedDescriptionKey:message}];
  return NO;
}

static inline BOOL rice_wallpaper_name_matches(NSString *first, NSString *second) {
  return [first isKindOfClass:NSString.class] && [second isKindOfClass:NSString.class] &&
    [first.precomposedStringWithCanonicalMapping isEqual:second.precomposedStringWithCanonicalMapping];
}

static inline NSURL *rice_wallpaper_source(NSString *config, NSString *name) {
  for (NSURL *file in rice_asset_files(config, @"wallpapers"))
    if (rice_wallpaper_name_matches(file.lastPathComponent, name)) return file;
  return nil;
}

static inline NSDictionary *rice_wallpaper_appearance(CGImageSourceRef source) {
  CGImageMetadataRef metadata = CGImageSourceCopyMetadataAtIndex(source, 0, NULL);
  if (!metadata) return nil;
  CFTypeRef value = CGImageMetadataCopyStringValueWithPath(metadata, NULL, CFSTR("apple_desktop:apr"));
  CFRelease(metadata);
  NSString *encoded = CFBridgingRelease(value);
  NSData *data = encoded ? [[NSData alloc] initWithBase64EncodedString:encoded options:0] : nil;
  id map = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL] : nil;
  return [map isKindOfClass:NSDictionary.class] ? map : nil;
}

static inline BOOL rice_wallpaper_is_pair(NSURL *url) {
  CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
  if (!source) return NO;
  BOOL valid = CGImageSourceGetCount(source) == 2 && [rice_wallpaper_appearance(source) isEqual:@{@"l":@0, @"d":@1}];
  CFRelease(source);
  return valid;
}

// Runs off the UI thread. Originals keep their own dimensions and orientation;
// different aspect ratios are intentional, and macOS crops each to the display.
static inline NSURL *rice_wallpaper_pair(NSString *config, NSDictionary *names, NSError **error) {
  NSURL *light = rice_wallpaper_source(config, names[@"light"]);
  NSURL *dark = rice_wallpaper_source(config, names[@"dark"]);
  if (!light || !dark) {
    rice_wallpaper_error(error, @"Choose an available wallpaper for both Light and Dark."); return nil;
  }
  rice_prepare_assets(config);
  NSString *identity = [NSString stringWithFormat:@"appearance-v1|%@|%@", rice_asset_cache_key(light), rice_asset_cache_key(dark)];
  NSData *key = [identity dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(key.bytes, (CC_LONG)key.length, digest);
  NSMutableString *hash = [NSMutableString string];
  for (NSUInteger i = 0; i < sizeof(digest); i++) [hash appendFormat:@"%02x", digest[i]];
  NSString *folder = [rice_asset_directory(config, @"cache") stringByAppendingPathComponent:[@"appearance-" stringByAppendingString:hash]];
  if (![NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:error]) return nil;
  NSURL *output = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"Rice Light & Dark.heic"]];
  if (rice_wallpaper_is_pair(output)) return output;
  NSURL *temporary = [NSURL fileURLWithPath:[output.path stringByAppendingFormat:@".%@.heic", NSUUID.UUID.UUIDString]];
  CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)temporary, CFSTR("public.heic"), 2, NULL);
  if (!destination) { rice_wallpaper_error(error, @"The macOS HEIC encoder is unavailable."); return nil; }
  CGMutableImageMetadataRef metadata = CGImageMetadataCreateMutable();
  BOOL valid = CGImageMetadataRegisterNamespaceForPrefix(metadata,
    CFSTR("http://ns.apple.com/namespace/1.0/"), CFSTR("apple_desktop"), NULL);
  NSData *map = [NSPropertyListSerialization dataWithPropertyList:@{@"l":@0, @"d":@1}
    format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
  CGImageMetadataTagRef tag = map ? CGImageMetadataTagCreate(CFSTR("http://ns.apple.com/namespace/1.0/"),
    CFSTR("apple_desktop"), CFSTR("apr"), kCGImageMetadataTypeString, (__bridge CFStringRef)[map base64EncodedStringWithOptions:0]) : NULL;
  valid = valid && tag && CGImageMetadataSetTagWithPath(metadata, NULL, CFSTR("apple_desktop:apr"), tag);
  if (tag) CFRelease(tag);
  NSUInteger index = 0;
  for (NSURL *url in @[light, dark]) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    size_t primary = source ? CGImageSourceGetPrimaryImageIndex(source) : 0;
    CGImageRef image = source ? CGImageSourceCreateImageAtIndex(source, primary, NULL) : NULL;
    if (image && valid) {
      NSMutableDictionary *options = [@{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality:@1.0} mutableCopy];
      NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, primary, NULL));
      if (properties[(__bridge NSString *)kCGImagePropertyOrientation])
        options[(__bridge NSString *)kCGImagePropertyOrientation] = properties[(__bridge NSString *)kCGImagePropertyOrientation];
      if (index == 0) CGImageDestinationAddImageAndMetadata(destination, image, metadata, (__bridge CFDictionaryRef)options);
      else CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    } else valid = NO;
    if (image) CGImageRelease(image);
    if (source) CFRelease(source);
    index++;
  }
  valid = valid && CGImageDestinationFinalize(destination);
  CFRelease(metadata); CFRelease(destination);
  valid = valid && rice_wallpaper_is_pair(temporary);
  if (valid) {
    // A stale/corrupt cache entry is replaced, never a user's source image.
    NSData *data = [NSData dataWithContentsOfURL:temporary];
    valid = data && [data writeToURL:output options:NSDataWritingAtomic error:error];
  }
  [NSFileManager.defaultManager removeItemAtURL:temporary error:NULL];
  if (!valid) { rice_wallpaper_error(error, @"Could not encode the light/dark wallpaper pair. Originals were not changed."); return nil; }
  return output;
}

// macOS 14+: NSWorkspace's setter clears Show on all Spaces. Update the native
// global entry instead. Preserve dormant per-Space/display choices and savers.
// No appearance callback calls this: WallpaperAgent reads the HEIC on its own.
static inline NSDictionary *rice_wallpaper_global_store(NSDictionary *store, NSURL *url, NSError **error) {
  if (![store isKindOfClass:NSDictionary.class] || !store[@"AllSpacesAndDisplays"] ||
      (![store[@"AllSpacesAndDisplays"] isKindOfClass:NSDictionary.class] && ![store[@"AllSpacesAndDisplays"] isEqual:@"$null"]) ||
      ![store[@"Spaces"] isKindOfClass:NSDictionary.class] || ![store[@"Displays"] isKindOfClass:NSDictionary.class] ||
      ![store[@"SystemDefault"] isKindOfClass:NSDictionary.class] || !url.isFileURL) {
    rice_wallpaper_error(error, @"This macOS wallpaper-store format is not supported. Use System Settings → Wallpaper instead."); return nil;
  }
  NSData *configuration = [NSPropertyListSerialization dataWithPropertyList:
    @{@"type":@"imageFile", @"url":@{@"relative":url.absoluteString}}
    format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
  NSData *options = [NSPropertyListSerialization dataWithPropertyList:
    @{@"values":@{@"placement":@{@"picker":@{@"id":@"Crop"}}}}
    format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
  if (!configuration || !options) return nil;
  NSMutableDictionary *next = [store mutableCopy];
  id old = store[@"AllSpacesAndDisplays"];
  NSMutableDictionary *global = [old isKindOfClass:NSDictionary.class] ? [old mutableCopy] : [NSMutableDictionary dictionary];
  if ([global[@"Type"] isEqual:@"linked"] && global[@"Linked"] && !global[@"Idle"])
    global[@"Idle"] = global[@"Linked"];
  [global removeObjectForKey:@"Linked"];
  NSDate *now = NSDate.date;
  global[@"Desktop"] = @{@"Content":@{@"Choices":@[@{@"Provider":@"com.apple.wallpaper.choice.image",
    @"Configuration":configuration, @"Files":@[]}], @"EncodedOptionValues":options, @"Shuffle":@"$null"},
    @"LastSet":now, @"LastUse":now};
  global[@"Type"] = global[@"Idle"] ? @"individual" : @"desktop";
  if ([old isKindOfClass:NSDictionary.class] && !old[@"Linked"] &&
      [old[@"Type"] isEqual:global[@"Type"]] && [old[@"Desktop"][@"Content"] isEqual:global[@"Desktop"][@"Content"]])
    return store; // Clicking the already-selected artwork must not flash/restart.
  next[@"AllSpacesAndDisplays"] = global;
  return next;
}

static inline NSArray<NSNumber *> *rice_wallpaper_agent_pids(void) {
  int count = proc_listallpids(NULL, 0);
  if (count <= 0) return @[];
  pid_t *pids = calloc((size_t)count + 128, sizeof(pid_t));
  count = proc_listallpids(pids, (count+128) * (int)sizeof(pid_t));
  NSMutableArray *agents = [NSMutableArray array];
  for (int i = 0; i < count; i++) {
    struct proc_bsdinfo info = {0}; char name[64] = {0};
    if (pids[i] > 1 && proc_name(pids[i], name, sizeof(name)) > 0 && !strcmp(name, "WallpaperAgent") &&
        proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &info, sizeof(info)) == sizeof(info) && info.pbi_uid == getuid())
      [agents addObject:@(pids[i])];
  }
  free(pids); return agents;
}

static inline BOOL rice_wallpaper_apply_all_spaces(NSString *config, NSURL *url, NSError **error) {
  if (!rice_asset_thumbnail(url)) return rice_wallpaper_error(error, @"Cannot open this wallpaper.");
  NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/com.apple.wallpaper/Store/Index.plist"];
  NSData *before = [NSData dataWithContentsOfFile:path options:0 error:error];
  id store = before ? [NSPropertyListSerialization propertyListWithData:before options:0 format:NULL error:error] : nil;
  NSDictionary *next = rice_wallpaper_global_store(store, url, error);
  if (next && [next isEqual:store]) return YES;
  NSArray *agents = rice_wallpaper_agent_pids();
  if (!next) return NO;
  if (!agents.count) return rice_wallpaper_error(error, @"The macOS wallpaper service is unavailable. Unlock your Mac and try again.");
  rice_prepare_assets(config);
  NSString *backup = [rice_asset_directory(config, @"cache") stringByAppendingPathComponent:@"wallpaper-store-before-all-spaces.plist"];
  if (![NSFileManager.defaultManager fileExistsAtPath:backup] && ![before writeToFile:backup options:NSDataWritingWithoutOverwriting error:error]) return NO;
  NSData *data = [NSPropertyListSerialization dataWithPropertyList:next format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
  // Don't overwrite a simultaneous choice made in System Settings.
  if (![[NSData dataWithContentsOfFile:path] isEqual:before])
    return rice_wallpaper_error(error, @"Wallpaper settings changed during the update. Please try again.");
  if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
  BOOL refreshed = NO;
  for (NSNumber *pid in agents) refreshed |= kill(pid.intValue, SIGTERM) == 0;
  if (!refreshed) {
    [before writeToFile:path options:NSDataWritingAtomic error:NULL];
    return rice_wallpaper_error(error, @"Could not refresh the wallpaper service. The previous settings were restored.");
  }
  return YES;
}
