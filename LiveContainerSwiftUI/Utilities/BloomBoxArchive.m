#import "BloomBoxArchive.h"
#include "archive.h"
#include "archive_entry.h"
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

static BOOL fail(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"BloomBoxBackup" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
static NSString *archiveMessage(struct archive *a) {
    const char *message = archive_error_string(a);
    return message ? [NSString stringWithUTF8String:message] : @"No se pudo procesar la copia.";
}
static BOOL safePath(NSString *path) {
    if (!path.length || path.isAbsolutePath || [path containsString:@"\\"]) return NO;
    for (NSString *part in [path componentsSeparatedByString:@"/"]) {
        if ([part isEqualToString:@".."] || [part isEqualToString:@"."]) return NO;
    }
    return YES;
}
@implementation BloomBoxArchive
+ (BOOL)packDirectory:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    struct archive *a = archive_write_new();
    archive_write_set_format_zip(a);
    if (archive_write_open_filename(a, destination.fileSystemRepresentation) != ARCHIVE_OK) {
        NSString *message = archiveMessage(a); archive_write_free(a); return fail(error, message);
    }
    __block NSError *walkError = nil;
    NSDirectoryEnumerator *walk = [fm enumeratorAtURL:source includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL *url, NSError *e) { walkError = e; return NO; }];
    BOOL success = walk != nil;
    NSString *message = @"No se pudo leer la carpeta de datos.";
    for (NSURL *url in walk) {
        @autoreleasepool {
            NSString *relative = [url.path substringFromIndex:source.path.length + 1];
            struct stat st;
            if (!safePath(relative) || lstat(url.fileSystemRepresentation, &st) != 0 || (!S_ISREG(st.st_mode) && !S_ISDIR(st.st_mode))) {
                success = NO; message = @"La copia contiene un enlace o archivo especial no compatible."; break;
            }
            struct archive_entry *entry = archive_entry_new();
            archive_entry_set_pathname(entry, relative.UTF8String);
            archive_entry_copy_stat(entry, &st);
            if (S_ISDIR(st.st_mode)) archive_entry_set_size(entry, 0);
            int status = archive_write_header(a, entry);
            archive_entry_free(entry);
            if (status != ARCHIVE_OK) { success = NO; message = archiveMessage(a); break; }
            if (S_ISREG(st.st_mode)) {
                int fd = open(url.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW);
                if (fd < 0) { success = NO; message = @"No se pudo leer un archivo de la app."; break; }
                char buffer[65536]; ssize_t count; int64_t total = 0;
                while ((count = read(fd, buffer, sizeof(buffer))) > 0) {
                    if (archive_write_data(a, buffer, count) != count) { success = NO; message = archiveMessage(a); break; }
                    total += count;
                }
                close(fd);
                if (count < 0 || total != st.st_size) { success = NO; message = @"Los datos cambiaron durante la copia. Cierra la app y vuelve a intentarlo."; }
                if (!success) break;
            }
            if (archive_write_finish_entry(a) != ARCHIVE_OK) { success = NO; message = archiveMessage(a); break; }
        }
    }
    if (walkError) { success = NO; message = walkError.localizedDescription; }
    if (archive_write_close(a) != ARCHIVE_OK) { success = NO; message = archiveMessage(a); }
    archive_write_free(a);
    if (!success) { [fm removeItemAtURL:destination error:nil]; return fail(error, message); }
    return YES;
}
+ (BOOL)unpackFile:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    // Never extract into an existing tree, where a pre-existing symlink could redirect writes.
    if ([fm fileExistsAtPath:destination.path]) return fail(error, @"La carpeta temporal ya existe.");
    if (![fm createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    struct archive *a = archive_read_new();
    archive_read_support_format_zip(a);
    BOOL success = archive_read_open_filename(a, source.fileSystemRepresentation, 65536) == ARCHIVE_OK;
    NSString *message = success ? @"Copia dañada o incompatible." : archiveMessage(a);
    struct archive_entry *entry;
    int status = ARCHIVE_OK; uint64_t total = 0; NSUInteger entries = 0;
    NSMutableSet *paths = [NSMutableSet set];
    // Limit both advertised and actual output. Large but finite, without loading ZIPs into RAM.
    const uint64_t limit = 64ULL * 1024 * 1024 * 1024;
    while (success && (status = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char *raw = archive_entry_pathname(entry);
        NSString *path = raw ? [NSString stringWithUTF8String:raw] : nil;
        mode_t type = archive_entry_filetype(entry);
        NSString *canonical = path.stringByStandardizingPath;
        if (!safePath(path) || [paths containsObject:canonical] || ++entries > 250000 ||
            archive_entry_symlink(entry) || archive_entry_hardlink(entry) ||
            (type != AE_IFREG && type != AE_IFDIR) || archive_entry_size(entry) < 0 ||
            (uint64_t)archive_entry_size(entry) > limit - total) {
            success = NO; message = @"La copia contiene rutas, enlaces o tamaños no válidos."; break;
        }
        [paths addObject:canonical];
        NSURL *target = [destination URLByAppendingPathComponent:path];
        NSURL *parent = type == AE_IFDIR ? target : target.URLByDeletingLastPathComponent;
        if (![fm createDirectoryAtURL:parent withIntermediateDirectories:YES attributes:nil error:error]) { success = NO; break; }
        if (type == AE_IFDIR) continue;
        int fd = open(target.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
        if (fd < 0) { success = NO; message = @"No se pudo crear un archivo de la copia."; break; }
        char buffer[65536]; la_ssize_t count; int64_t fileSize = 0;
        while ((count = archive_read_data(a, buffer, sizeof(buffer))) > 0) {
            if ((uint64_t)count > limit - total) { success = NO; break; }
            total += count; fileSize += count;
            ssize_t offset = 0;
            while (offset < count) {
                ssize_t written = write(fd, buffer + offset, count - offset);
                if (written <= 0) { success = NO; break; }
                offset += written;
            }
            if (!success) break;
        }
        if (close(fd) != 0) success = NO;
        if (count < 0 || fileSize != archive_entry_size(entry)) success = NO;
        if (!success) { message = @"Copia dañada, demasiado grande o sin espacio disponible."; break; }
        // Do not restore ownership, ACLs, setuid or executable permission from imported data.
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:archive_entry_mtime(entry)];
        [fm setAttributes:@{NSFileModificationDate: date} ofItemAtPath:target.path error:nil];
    }
    if (success && status != ARCHIVE_EOF) { success = NO; message = archiveMessage(a); }
    archive_read_free(a);
    if (!success) { [fm removeItemAtURL:destination error:nil]; return fail(error, message); }
    return YES;
}
@end
