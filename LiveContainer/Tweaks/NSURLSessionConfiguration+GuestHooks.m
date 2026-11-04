//
//  NSURLSessionConfiguration+GuestHooks.m
//  LiveContainer
//
//  Created by Duy Tran on 27/6/26.
//
#import "utils.h"
#import "LCSharedUtils.h"

@implementation NSURLSessionConfiguration(LiveContainerHook)
- (void)hook_encodeWithCoder:(NSCoder *)coder {
    // Fix background download failing in LiveProcess. We always overwrite sharedContainerIdentifier with ours.
    self.sharedContainerIdentifier = LCSharedUtils.appGroupID;
    [self hook_encodeWithCoder:coder];
}
@end

void NSURLSCGuestHooksInit(void) {
    swizzle(NSURLSessionConfiguration.class, @selector(encodeWithCoder:), @selector(hook_encodeWithCoder:));
}


// BloomBox's experimental per-guest offline mode.
// The hooks are process-local and deliberately preserve AF_UNIX/IPC sockets.
// This is NOT an iOS firewall. A network daemon, a native Network.framework
// path or another guest sharing this process can behave differently.
#include <errno.h>
#include <string.h>
#include <netdb.h>
#include <sys/socket.h>
#include "../../litehook/src/litehook.h"

static int (*lcRealSocket)(int, int, int) = socket;
static int (*lcRealConnect)(int, const struct sockaddr *, socklen_t) = connect;
static ssize_t (*lcRealSendto)(int, const void *, size_t, int, const struct sockaddr *, socklen_t) = sendto;
static ssize_t (*lcRealSendmsg)(int, const struct msghdr *, int) = sendmsg;
static int (*lcRealGetaddrinfo)(const char *, const char *, const struct addrinfo *, struct addrinfo **) = getaddrinfo;

static BOOL lcIsInternetFamily(sa_family_t family) {
    return family == AF_INET || family == AF_INET6;
}

static int lcBlockedSocket(int domain, int type, int protocol) {
    if (lcIsInternetFamily((sa_family_t)domain)) {
        errno = ENETUNREACH;
        return -1;
    }
    return lcRealSocket(domain, type, protocol);
}

static int lcBlockedConnect(int fd, const struct sockaddr *address, socklen_t size) {
    if (address && lcIsInternetFamily(address->sa_family)) {
        errno = ENETUNREACH;
        return -1;
    }
    return lcRealConnect(fd, address, size);
}

static BOOL lcBlockedSocketAddress(int fd, const struct sockaddr *address) {
    if (address) return lcIsInternetFamily(address->sa_family);
    // If the address is omitted, the socket might already be connected.
    struct sockaddr_storage local = {0};
    socklen_t length = sizeof(local);
    if (getsockname(fd, (struct sockaddr *)&local, &length) == 0) {
        return lcIsInternetFamily(local.ss_family);
    }
    return NO; // Do not disrupt unrelated UNIX IPC.
}

static ssize_t lcBlockedSendto(int fd, const void *buffer, size_t size, int flags,
                               const struct sockaddr *address, socklen_t addressLength) {
    if (lcBlockedSocketAddress(fd, address)) {
        errno = ENETUNREACH;
        return -1;
    }
    return lcRealSendto(fd, buffer, size, flags, address, addressLength);
}

static ssize_t lcBlockedSendmsg(int fd, const struct msghdr *message, int flags) {
    const struct sockaddr *address = message ? message->msg_name : NULL;
    if (lcBlockedSocketAddress(fd, address)) {
        errno = ENETUNREACH;
        return -1;
    }
    return lcRealSendmsg(fd, message, flags);
}

static int lcBlockedGetaddrinfo(const char *name, const char *service,
                                const struct addrinfo *hints, struct addrinfo **result) {
    // DNS resolution through the app process must not leak a hostname.
    if (name && name[0] && strcmp(name, "localhost") != 0) {
        return EAI_NONAME;
    }
    return lcRealGetaddrinfo(name, service, hints, result);
}

void LCNetworkBlockInit(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, socket, lcBlockedSocket, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, connect, lcBlockedConnect, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sendto, lcBlockedSendto, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, sendmsg, lcBlockedSendmsg, nil);
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, getaddrinfo, lcBlockedGetaddrinfo, nil);
        NSLog(@"[BloomBox] Experimental network block activated for this guest process");
    });
}
