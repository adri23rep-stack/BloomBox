#import <Foundation/Foundation.h>
#import "BloomBoxArchive.h"
#include "archive.h"
#include "archive_entry.h"

static void require(BOOL condition, NSString *why) {
    if (!condition) { NSLog(@"FAIL: %@", why); exit(1); }
}

static void hostileArchive(NSURL *file, const char *path, mode_t mode) {
    struct archive *a = archive_write_new();
    archive_write_set_format_zip(a);
    require(archive_write_open_filename(a, file.fileSystemRepresentation) == ARCHIVE_OK,
            @"Fixture ZIP open failed");
    struct archive_entry *entry = archive_entry_new();
    archive_entry_set_pathname(entry, path);
    archive_entry_set_filetype(entry, mode);
    archive_entry_set_perm(entry, 0600);
    archive_entry_set_size(entry, 0);
    if (mode == AE_IFLNK) archive_entry_set_symlink(entry, "../../escape");
    require(archive_write_header(a, entry) == ARCHIVE_OK, @"Fixture ZIP entry failed");
    archive_entry_free(entry);
    archive_write_close(a);
    archive_write_free(a);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        require(argc == 2, @"Usage: playnite_test original.pthm");
        NSFileManager *fm = NSFileManager.defaultManager;
        NSError *error = nil;
        NSURL *root = [NSURL fileURLWithPath:
            [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        require([fm createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:&error],
                @"Temp folder");
        NSURL *package = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSURL *extracted = [root URLByAppendingPathComponent:@"original"];
        require([BloomBoxArchive unpackPlayniteTheme:package toURL:extracted error:&error],
                error.description ?: @"Original Playnite extraction failed");
        NSString *yaml = [NSString stringWithContentsOfURL:
            [extracted URLByAppendingPathComponent:@"theme.yaml"] encoding:NSUTF8StringEncoding
            error:&error];
        require([yaml containsString:@"Nintendo Switch-ish_0d020ed5-0f3c-4c1a-bf9a-c983ef7d74b7"],
                @"Original theme identity");
        require([fm fileExistsAtPath:
            [extracted URLByAppendingPathComponent:@"Constants.xaml"].path], @"Original colors present");
        require([fm fileExistsAtPath:
            [extracted URLByAppendingPathComponent:@"Views/Main.xaml"].path], @"Original layout present");
        require([fm fileExistsAtPath:
            [extracted URLByAppendingPathComponent:@"Images/applogo_clean.png"].path],
            @"Original image present");
        require(![BloomBoxArchive unpackPlayniteTheme:package toURL:extracted error:&error],
                @"Must not overwrite an existing theme directory");

        NSArray *unsafe = @[@"../../escape.png", @"/absolute.png", @"a/../escape.png", @"a\\..\\escape.png"];
        for (NSString *name in unsafe) {
            NSURL *bad = [root URLByAppendingPathComponent:@"unsafe.zip"];
            hostileArchive(bad, name.UTF8String, AE_IFREG);
            NSURL *target = [root URLByAppendingPathComponent:@"rejected"];
            require(![BloomBoxArchive unpackPlayniteTheme:bad toURL:target error:&error],
                    @"Reject unsafe file path");
            require(![fm fileExistsAtPath:target.path], @"Remove rejected extraction");
            [fm removeItemAtURL:bad error:nil];
        }
        NSURL *linkZip = [root URLByAppendingPathComponent:@"link.zip"];
        hostileArchive(linkZip, "Images/rogue.png", AE_IFLNK);
        require(![BloomBoxArchive unpackPlayniteTheme:linkZip
            toURL:[root URLByAppendingPathComponent:@"link"] error:&error],
            @"Reject archive symlink");

        require(![fm fileExistsAtPath:[root URLByAppendingPathComponent:@"escape.png"].path],
                @"Never write outside extraction");
        [fm removeItemAtURL:root error:nil];
        NSLog(@"PASS: authentic .pthm extraction, original XAML/art, no overwrite, traversal, links");
        return 0;
    }
}
