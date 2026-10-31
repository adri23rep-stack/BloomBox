//
//  main.m
//  LiveProcess
//
//  Created by Duy Tran on 3/5/25.
//

#import <dlfcn.h>
#import <Security/Security.h>
#import "../LiveContainer/LCSharedUtils.h"
#import "../LiveContainer/FoundationPrivate.h"
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import "../LiveContainer/utils.h"
#import "../LiveContainer/Tweaks/Tweaks.h"
#import "../SideStoreSupport/XPCServer.h"

@interface LiveProcessHandler : NSObject<NSExtensionRequestHandling>
@end
@implementation LiveProcessHandler
static NSExtensionContext *extensionContext;
static NSDictionary *retrievedAppInfo;
+ (NSExtensionContext *)extensionContext {
    return extensionContext;
}

+ (NSDictionary *)retrievedAppInfo {
    return retrievedAppInfo;
}

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    extensionContext = context;
    retrievedAppInfo = [context.inputItems.firstObject userInfo];
    // Return control to LiveContainerMain
    CFRunLoopStop(CFRunLoopGetMain());
}
@end

// Read the actual extension signature before guest hooks can replace bundle identity.
static void BloomBoxReportJITPermissions(void) {
    void *task = SecTaskCreateFromSelf(NULL);
    if (!task) return;
    NSMutableDictionary *report = [@{@"pid": @(getpid()),
        @"timestamp": @([NSDate date].timeIntervalSince1970)} mutableCopy];
    NSDictionary *keys = @{@"debug": @"get-task-allow",
        @"ram": @"com.apple.developer.kernel.increased-memory-limit"};
    for (NSString *name in keys) {
        CFErrorRef error = NULL;
        CFTypeRef value = SecTaskCopyValueForEntitlement(task, (__bridge CFStringRef)keys[name], &error);
        if (!error) report[name] = @(value && CFGetTypeID(value) == CFBooleanGetTypeID() && CFEqual(value, kCFBooleanTrue));
        if (value) CFRelease(value);
        if (error) CFRelease(error);
    }
    CFRelease(task);
    NSURL *root = [LCSharedUtils appGroupPath];
    if (!root) return;
    NSURL *directory = [root URLByAppendingPathComponent:@"Library/StrataJIT/Targets" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *file = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%d.json", getpid()]];
    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:0 error:nil];
    [data writeToURL:file options:NSDataWritingAtomic error:nil];
}

extern int LiveContainerMain(int argc, char *argv[]);
static char **_envp, **_apple = NULL;
int LiveProcessMain(int argc, char *argv[]) {
    // Let NSExtensionContext initialize, once it's done it will call CFRunLoopStop
    CFRunLoopRun();
    // Ensure app info is delivered
    NSDictionary *appInfo = LiveProcessHandler.retrievedAppInfo;
    NSCAssert(appInfo, @"Failed to retrieve app info");
    BloomBoxReportJITPermissions();
    
    // Check if we received a request to execute a custom payload
    NSString *customPayloadDylib = appInfo[@"customPayloadDylib"];
    if(customPayloadDylib) {
        void *handle = dlopen(customPayloadDylib.fileSystemRepresentation, RTLD_LAZY);
        NSCAssert(appInfo, @"Failed to load custom payload dylib at path: %@", customPayloadDylib);
        
        NSString *customPayloadEntry = appInfo[@"customPayloadEntry"];
        NSCAssert(customPayloadEntry, @"Missing customPayloadEntry");
        int (*payloadEntry)(int, char **, char **, char **) = dlsym(handle, customPayloadEntry.UTF8String);
        return payloadEntry(argc, argv, _envp, _apple);
    }
    
    NSLog(@"Retrieved app info: %@", appInfo);
    // Set LiveContainer's home path
    setenv("LP_HOME_PATH", getenv("HOME"), 1);
    const char *overrideHomePath = [appInfo[@"lcHomePath"] fileSystemRepresentation];
    if(overrideHomePath) setenv("LC_HOME_PATH", overrideHomePath, 1);
    // Pass selected app info to user defaults
    NSUserDefaults *lcUserDefaults = NSUserDefaults.standardUserDefaults;
    [lcUserDefaults setObject:appInfo[@"hostUrlScheme"] forKey:@"hostUrlScheme"];
    [lcUserDefaults setObject:appInfo[@"launchAppUrlScheme"] forKey:@"launchAppUrlScheme"];
    [lcUserDefaults setObject:appInfo[@"selected"] forKey:@"selected"];
    [lcUserDefaults setObject:appInfo[@"selectedContainer"] forKey:@"selectedContainer"];
    
    BOOL access = NO;
    NSArray<NSData *> *bookmarks = appInfo[@"bookmarks"];
    NSMutableArray<NSURL *> *bookmarkedUrls = [NSMutableArray array];
    for (NSData *bookmark in bookmarks) {
        BOOL isStale = NO;
        NSError *error = nil;
        NSURL *scopedURL = [NSURL URLByResolvingBookmarkData:bookmark options:0
            relativeToURL:nil bookmarkDataIsStale:&isStale error:&error];
        // A private bundle needs a valid bookmark before the guest's main()
        // can initialize. Otherwise it may silently return code 0.
        if (!scopedURL) {
            NSString *description = [NSString stringWithFormat:
                @"LiveProcess no pudo resolver el acceso privado (%@). Puedes probar 'Allow Private Data access from LiveProcess' en Ajustes de desarrollador de BloomBox.",
                error.localizedDescription ?: @"bookmark inválido"];
            NSLog(@"[BloomBox] %@", description);
            NSError *launchError = [NSError errorWithDomain:@"BloomBox.LiveProcess"
                code:103 userInfo:@{NSLocalizedDescriptionKey:description}];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)),
                dispatch_get_main_queue(), ^{
                    [LiveProcessHandler.extensionContext cancelRequestWithError:launchError];
                    exit(1);
                });
            CFRunLoopRun();
            return 1;
        }
        BOOL started = [scopedURL startAccessingSecurityScopedResource];
        access = access || started;
        [bookmarkedUrls addObject:scopedURL];
        if (!started && [appInfo[@"privateGuest"] boolValue] &&
            ![NSFileManager.defaultManager fileExistsAtPath:scopedURL.path]) {
            NSString *description = [NSString stringWithFormat:
                @"LiveProcess no tiene permiso para acceder a %@. Prueba la opción de acceso a datos privados en Ajustes de desarrollador de BloomBox.",
                scopedURL.lastPathComponent];
            NSLog(@"[BloomBox] %@", description);
            NSError *launchError = [NSError errorWithDomain:@"BloomBox.LiveProcess"
                code:104 userInfo:@{NSLocalizedDescriptionKey:description}];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)),
                dispatch_get_main_queue(), ^{
                    [LiveProcessHandler.extensionContext cancelRequestWithError:launchError];
                    exit(1);
                });
            CFRunLoopRun();
            return 1;
        }
    }
    NSLog(@"[BloomBox] LiveProcess: private=%@, scopedBookmarks=%lu, accessGranted=%@",
        [appInfo[@"privateGuest"] boolValue] ? @"YES" : @"NO",
        (unsigned long)bookmarkedUrls.count, access ? @"YES" : @"NO");
    
    if ([appInfo[@"selected"] isEqualToString:@"builtinSideStore"]) {
        if(access && bookmarkedUrls.count > 0) {
            [lcUserDefaults setObject:bookmarkedUrls.firstObject.path forKey:@"specifiedSideStoreContainerPath"];
        }
        NSXPCListenerEndpoint* endpoint = appInfo[@"endpoint"];

        NSXPCConnection* connection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
        connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(RefreshServer)];
        connection.interruptionHandler = ^{
            NSLog(@"interrupted!!!");
        };
        
        [connection activate];
        
        NSObject<RefreshServer>* proxy = [connection remoteObjectProxy];
        LiveProcessSideStoreHandler.shared.server = proxy;
        LiveProcessSideStoreHandler.shared.connection = connection;
        
    }

    
    return LiveContainerMain(argc, argv);
}

// this is our fake UIApplicationMain called from _xpc_objc_uimain (xpc_main)
__attribute__((visibility("default")))
int UIApplicationMain(int argc, char * argv[], NSString * principalClassName, NSString * delegateClassName) {
    return LiveProcessMain(argc, argv);
}

// NSExtensionMain will load UIKit and call UIApplicationMain, so we need to redirect it to our fake one
static void* (*orig_dlopen)(void* dyldApiInstancePtr, const char* path, int mode);
static void* hook_dlopen(void* dyldApiInstancePtr, const char* path, int mode) {
    const char *UIKitFrameworkPath = "/System/Library/Frameworks/UIKit.framework/UIKit";
    if(path && !strncmp(path, UIKitFrameworkPath, strlen(UIKitFrameworkPath))) {
        // switch back to original dlopen
        performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, orig_dlopen);
        // FIXME: may be incompatible with jailbreak tweaks?
        return RTLD_MAIN_ONLY;
    } else {
        __attribute__((musttail)) return orig_dlopen(dyldApiInstancePtr, path, mode);
    }
}

// Extension entry point
int NSExtensionMain(int argc, char *argv[], char *envp[], char *apple[]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    method_setImplementation(class_getInstanceMethod(NSClassFromString(@"NSXPCDecoder"), @selector(_validateAllowedClass:forKey:allowingInvocations:)), (IMP)hook_do_nothing);
#pragma clang diagnostic pop
    // hook dlopen UIKit
    performHookDyldApi("dlopen", 2, (void**)&orig_dlopen, hook_dlopen);
    // call the real one
    _envp = envp;
    _apple = apple;
    int (*orig_NSExtensionMain)(int argc, char * argv[]) = dlsym(RTLD_NEXT, "NSExtensionMain");
    return orig_NSExtensionMain(argc, argv);
}
