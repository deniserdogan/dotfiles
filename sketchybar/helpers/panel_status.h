// GPL-3.0. Native telemetry; sampled only while the control panel is visible.
#pragma once
#import <AppKit/AppKit.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <net/route.h>
#include <net/if.h>
#include <netinet/in.h>

static inline BOOL rice_proxy_enabled(NSDictionary *proxies) {
  for (NSString *key in @[(__bridge NSString *)kSCPropNetProxiesHTTPEnable,
      (__bridge NSString *)kSCPropNetProxiesHTTPSEnable,
      (__bridge NSString *)kSCPropNetProxiesSOCKSEnable,
      (__bridge NSString *)kSCPropNetProxiesProxyAutoConfigEnable,
      (__bridge NSString *)kSCPropNetProxiesProxyAutoDiscoveryEnable])
    if ([proxies[key] boolValue]) return YES;
  return NO;
}

static inline NSString *rice_vpn_summary(BOOL tunnel, BOOL proxy) {
  if (tunnel && proxy) return @"●  VPN tunnel active  ·  System proxy enabled";
  if (tunnel) return @"●  VPN tunnel active";
  if (proxy) return @"●  System proxy enabled";
  return @"○  No VPN tunnel or system proxy detected";
}

static inline BOOL rice_vpn_route(void) {
  int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_DUMP2, 0};
  size_t size = 0;
  if (sysctl(mib, 6, NULL, &size, NULL, 0) || !size) return NO;
  char *data = malloc(size);
  if (sysctl(mib, 6, data, &size, NULL, 0)) { free(data); return NO; }
  BOOL low = NO, high = NO, defaultTunnel = NO;
  for (char *cursor = data; cursor + sizeof(struct rt_msghdr2) <= data + size;) {
    struct rt_msghdr2 *route = (void *)cursor;
    if (route->rtm_msglen < sizeof(*route) || cursor + route->rtm_msglen > data + size) break;
    char interface[IF_NAMESIZE] = {0};
    if_indextoname(route->rtm_index, interface);
    if (!strncmp(interface, "utun", 4) && (route->rtm_flags & RTF_UP)) {
      struct sockaddr *addresses[RTAX_MAX] = {0};
      char *next = (char *)(route + 1), *end = cursor + route->rtm_msglen;
      for (int i = 0; i < RTAX_MAX && next + 2 <= end; i++) if (route->rtm_addrs & (1 << i)) {
        struct sockaddr *address = (void *)next;
        size_t length = address->sa_len ? (address->sa_len + 3) & ~3 : 4;
        if (next + length > end) break;
        addresses[i] = address; next += length;
      }
      struct sockaddr_in *destination = (void *)addresses[RTAX_DST], *mask = (void *)addresses[RTAX_NETMASK];
      if (destination && destination->sin_len >= 8 && destination->sin_family == AF_INET) {
        uint32_t address = ntohl(destination->sin_addr.s_addr);
        uint32_t netmask = mask && mask->sin_len >= 8 ? ntohl(mask->sin_addr.s_addr) : 0;
        if (netmask == 0x80000000) { low |= address == 0; high |= address == 0x80000000; }
        if (address == 0 && netmask == 0) defaultTunnel = YES;
      }
    }
    cursor += route->rtm_msglen;
  }
  free(data);
  return defaultTunnel || (low && high);
}

static inline NSDictionary *rice_status(void) {
  static host_cpu_load_info_data_t previous;
  static BOOL sampled;
  host_cpu_load_info_data_t ticks;
  mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
  NSString *cpu = @"—";
  if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&ticks, &count) == KERN_SUCCESS) {
    uint64_t total = 0, idle = 0;
    for (int i = 0; i < CPU_STATE_MAX; i++) {
      uint32_t delta = ticks.cpu_ticks[i] - previous.cpu_ticks[i];
      total += delta; if (i == CPU_STATE_IDLE) idle = delta;
    }
    if (sampled && total) cpu = [NSString stringWithFormat:@"%.0f%%", 100.0 * (total-idle) / total];
    previous = ticks; sampled = YES;
  }
  vm_statistics64_data_t memory = {0};
  count = HOST_VM_INFO64_COUNT;
  host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&memory, &count);
  vm_size_t pageSize; host_page_size(mach_host_self(), &pageSize);
  double physical = NSProcessInfo.processInfo.physicalMemory;
  double used = MIN(physical, ((double)memory.active_count + memory.wire_count + memory.compressor_page_count) * pageSize);
  NSString *battery = @"AC", *powerDetail = @"External power";
  CFTypeRef power = IOPSCopyPowerSourcesInfo();
  if (power) {
    NSArray *sources = CFBridgingRelease(IOPSCopyPowerSourcesList(power));
    for (id source in sources) {
      NSDictionary *info = (__bridge NSDictionary *)IOPSGetPowerSourceDescription(power, (__bridge CFTypeRef)source);
      if (![info[@kIOPSTypeKey] isEqual:@kIOPSInternalBatteryType]) continue;
      double maximum = [info[@kIOPSMaxCapacityKey] doubleValue];
      if (maximum > 0) battery = [NSString stringWithFormat:@"%.0f%%", 100 * [info[@kIOPSCurrentCapacityKey] doubleValue] / maximum];
      powerDetail = [info[@kIOPSIsChargingKey] boolValue] ? @"Charging" :
        [info[@kIOPSPowerSourceStateKey] isEqual:@kIOPSACPowerValue] ? @"Plugged in" : @"On battery";
    }
    CFRelease(power);
  }
  NSNumber *capacity = nil, *available = nil;
  NSURL *volume = [NSURL fileURLWithPath:NSHomeDirectory()];
  [volume getResourceValue:&capacity forKey:NSURLVolumeTotalCapacityKey error:NULL];
  [volume getResourceValue:&available forKey:NSURLVolumeAvailableCapacityForImportantUsageKey error:NULL];
  double freeRatio = capacity.doubleValue > 0 ? available.doubleValue / capacity.doubleValue : 0;
  double load[3] = {0}; getloadavg(load, 3);
  NSDictionary *proxies = CFBridgingRelease(SCDynamicStoreCopyProxies(NULL));
  return @{@"cpu":cpu, @"load":[NSString stringWithFormat:@"Load %.2f · 1 min", load[0]],
    @"memory":[NSString stringWithFormat:@"%.0f%%", physical ? used / physical * 100 : 0],
    @"memoryDetail":[NSString stringWithFormat:@"%.1f / %.0f GB", used / 1073741824.0, physical / 1073741824.0],
    @"battery":battery, @"powerDetail":powerDetail,
    @"storage":[NSString stringWithFormat:@"%.0f GB free of %.0f GB", available.doubleValue / 1e9, capacity.doubleValue / 1e9],
    @"storageUsed":@(1-freeRatio), @"vpn":@(rice_vpn_route()), @"proxy":@(rice_proxy_enabled(proxies)),
    @"displays":[NSString stringWithFormat:@"%lu display%@ · %@", NSScreen.screens.count,
      NSScreen.screens.count == 1 ? @"" : @"s", NSScreen.mainScreen.localizedName ?: @"This Mac"]};
}
