#import <Foundation/Foundation.h>
#import "BloomBoxArchive.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            NSLog(@"Usage: import-tests <valid.deb> <unsafe.deb>");
            return 2;
        }
        NSFileManager *fm = NSFileManager.defaultManager;
        NSURL *folder = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent: NSUUID.UUID.UUIDString] isDirectory:YES];
        NSError *error = nil;
        NSURL *destination = [folder URLByAppendingPathComponent:@"valid"];
        if (![BloomBoxArchive importDEB:[NSURL fileURLWithPath:@(argv[1])]
                            toDirectory:destination error:&error]) {
            NSLog(@"Unexpected valid DEB error: %@", error);
            return 1;
        }
        if (![fm fileExistsAtPath:[[destination URLByAppendingPathComponent:@"BloomBoxDebProbe.dylib"] path]] ||
            ![fm fileExistsAtPath:[[destination URLByAppendingPathComponent:@"BloomBoxDebProbe.plist"] path]]) {
            NSLog(@"Missing imported tweak files.");
            return 1;
        }
        NSError *againError = nil;
        if ([BloomBoxArchive importDEB:[NSURL fileURLWithPath:@(argv[1])]
                           toDirectory:destination error:&againError]) {
            NSLog(@"Destination overwrite was accepted.");
            return 1;
        }
        NSURL *unsafe = [folder URLByAppendingPathComponent:@"unsafe"];
        NSError *unsafeError = nil;
        if ([BloomBoxArchive importDEB:[NSURL fileURLWithPath:@(argv[2])]
                           toDirectory:unsafe error:&unsafeError] ||
            [fm fileExistsAtPath:unsafe.path] ||
            [fm fileExistsAtPath:[[folder URLByAppendingPathComponent:@"escape.dylib"] path]]) {
            NSLog(@"Unsafe archive was not rejected correctly.");
            return 1;
        }
        [fm removeItemAtURL:folder error:nil];
        NSLog(@"PASS: .deb import, binary and filter, no overwrite, reject traversal");
        return 0;
    }
}
