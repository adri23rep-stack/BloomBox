#import <Foundation/Foundation.h>
#import "BloomBoxArchive.h"
#include "archive.h"
#include "archive_entry.h"
static void check(BOOL value, NSString *message) { if (!value) { NSLog(@"FAIL: %@", message); exit(1); } }
static void hostile(NSURL *zip, const char *path, mode_t type, int64_t size) {
    struct archive *a = archive_write_new(); archive_write_set_format_zip(a);
    check(archive_write_open_filename(a, zip.fileSystemRepresentation) == ARCHIVE_OK, @"create fixture");
    struct archive_entry *e = archive_entry_new();
    archive_entry_set_pathname(e, path); archive_entry_set_filetype(e, type);
    archive_entry_set_perm(e, 0600); archive_entry_set_size(e, size);
    if (type == AE_IFLNK) archive_entry_set_symlink(e, "../../outside");
    archive_write_header(a, e);
    archive_entry_free(e); archive_write_close(a); archive_write_free(a);
}
int main(void) { @autoreleasepool {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    NSURL *source = [root URLByAppendingPathComponent:@"source"];
    NSError *error = nil;
    check([fm createDirectoryAtURL:[source URLByAppendingPathComponent:@"Library/Preferences"] withIntermediateDirectories:YES attributes:nil error:&error], @"mkdir");
    check([fm createDirectoryAtURL:[source URLByAppendingPathComponent:@"Documents/Empty"] withIntermediateDirectories:YES attributes:nil error:&error], @"empty directory");
    NSMutableData *large = [NSMutableData dataWithLength:5 * 1024 * 1024 + 17];
    arc4random_buf(large.mutableBytes, large.length);
    check([large writeToURL:[source URLByAppendingPathComponent:@"Documents/partida.dat"] options:0 error:&error], @"write large file");
    NSData *prefs = [@"hidden preferences / ñ / 日本語" dataUsingEncoding:NSUTF8StringEncoding];
    check([prefs writeToURL:[source URLByAppendingPathComponent:@"Library/Preferences/.ajustes"] options:0 error:&error], @"write hidden file");
    NSURL *zip = [root URLByAppendingPathComponent:@"backup.zip"];
    check([BloomBoxArchive packDirectory:source toURL:zip error:&error], error.description);
    NSURL *output = [root URLByAppendingPathComponent:@"restored"];
    check([BloomBoxArchive unpackFile:zip toURL:output error:&error], error.description);
    check([[NSData dataWithContentsOfURL:[output URLByAppendingPathComponent:@"Documents/partida.dat"]] isEqual:large], @"streamed data roundtrip");
    check([[NSData dataWithContentsOfURL:[output URLByAppendingPathComponent:@"Library/Preferences/.ajustes"]] isEqual:prefs], @"hidden data roundtrip");
    check([fm fileExistsAtPath:[output URLByAppendingPathComponent:@"Documents/Empty"].path], @"empty folder roundtrip");
    check(![BloomBoxArchive unpackFile:zip toURL:output error:&error], @"reject existing target");
    NSArray *paths = @[@"../escape", @"/absolute", @"safe/../../escape", @"back\\slash"];
    for (NSString *path in paths) {
        NSURL *bad = [root URLByAppendingPathComponent:@"bad.zip"];
        hostile(bad, path.UTF8String, AE_IFREG, 0);
        NSURL *dest = [root URLByAppendingPathComponent:@"rejected"];
        check(![BloomBoxArchive unpackFile:bad toURL:dest error:&error], @"reject unsafe path");
        check(![fm fileExistsAtPath:dest.path], @"cleanup rejected archive");
    }
    NSURL *bad = [root URLByAppendingPathComponent:@"bad.zip"];
    hostile(bad, "link", AE_IFLNK, 0);
    check(![BloomBoxArchive unpackFile:bad toURL:[root URLByAppendingPathComponent:@"link-output"] error:&error], @"reject imported symlink");
    NSData *bytes = [NSData dataWithContentsOfURL:zip];
    [[bytes subdataWithRange:NSMakeRange(0, bytes.length / 2)] writeToURL:bad atomically:YES];
    check(![BloomBoxArchive unpackFile:bad toURL:[root URLByAppendingPathComponent:@"truncated"] error:&error], @"reject truncated data");
    check([fm createSymbolicLinkAtURL:[source URLByAppendingPathComponent:@"external"] withDestinationURL:root error:&error], @"create link fixture");
    check(![BloomBoxArchive packDirectory:source toURL:bad error:&error], @"reject source link rather than read outside data");
    check(![fm fileExistsAtPath:bad.path], @"cleanup failed export");
    check(![fm fileExistsAtPath:[root URLByAppendingPathComponent:@"escape"].path], @"no traversal write");
    [fm removeItemAtURL:root error:nil];
    NSLog(@"PASS: backup roundtrip, hidden files, empty directories, streaming, traversal, symlinks, truncation, cleanup");
    return 0;
} }
