// GPL-3.0: exact argv and asynchronous event transport for native helpers.
#pragma once
#import <Foundation/Foundation.h>
#include "vendor/sketchybar.h"

static inline BOOL rice_bar(NSArray<NSString *> *args) {
  if (!g_mach_port) g_mach_port = mach_get_bs_port();
  if (!g_mach_port) return NO;
  NSMutableData *message = [NSMutableData data];
  for (NSString *arg in args) {
    [message appendData:[arg dataUsingEncoding:NSUTF8StringEncoding]];
    [message appendBytes:"" length:1];
  }
  [message appendBytes:"" length:1];
  const char *reply = mach_send_message(g_mach_port, message.mutableBytes, (uint32_t)message.length);
  if (reply && strstr(reply, "[!]")) fprintf(stderr, "SketchyBar: %s\n", reply);
  return reply && !strstr(reply, "[!]");
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline mach_port_t rice_lookup(const char *name) {
  mach_port_t port = MACH_PORT_NULL;
  bootstrap_look_up(bootstrap_port, name, &port);
  return port;
}

static inline mach_port_t rice_register(const char *name) {
  mach_port_t port = MACH_PORT_NULL;
  if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS) return 0;
  mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
  kern_return_t result = bootstrap_register(bootstrap_port, (char *)name, port);
  if (result != KERN_SUCCESS) {
    fprintf(stderr, "Register %s: %s (%d)\n", name, bootstrap_strerror(result), result);
    mach_port_destroy(mach_task_self(), port);
    return 0;
  }
  return port;
}
#pragma clang diagnostic pop

static inline BOOL rice_post(const char *portName, NSDictionary<NSString *, NSString *> *values) {
  mach_port_t port = rice_lookup(portName);
  if (!port) return NO;
  NSMutableData *data = [NSMutableData data];
  for (NSString *key in values) {
    for (NSString *value in @[key, values[key]]) {
      [data appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
      [data appendBytes:"" length:1];
    }
  }
  [data appendBytes:"" length:1];
  struct mach_message message = {0};
  message.header.msgh_remote_port = port;
  message.header.msgh_bits = MACH_MSGH_BITS_SET(MACH_MSG_TYPE_COPY_SEND, 0, 0, MACH_MSGH_BITS_COMPLEX);
  message.header.msgh_size = sizeof(message);
  message.msgh_descriptor_count = 1;
  message.descriptor.address = data.mutableBytes;
  message.descriptor.size = (uint32_t)data.length;
  message.descriptor.copy = MACH_MSG_VIRTUAL_COPY;
  message.descriptor.type = MACH_MSG_OOL_DESCRIPTOR;
  kern_return_t result = mach_msg(&message.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT,
                                 sizeof(message), 0, MACH_PORT_NULL, 100, MACH_PORT_NULL);
  mach_port_deallocate(mach_task_self(), port);
  return result == MACH_MSG_SUCCESS;
}
