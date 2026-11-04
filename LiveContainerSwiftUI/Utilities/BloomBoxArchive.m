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
    source = source.URLByResolvingSymlinksInPath.URLByStandardizingPath;
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
            NSArray<NSString *> *base = source.pathComponents;
            NSArray<NSString *> *parts = url.URLByStandardizingPath.pathComponents;
            if (parts.count <= base.count || ![[parts subarrayWithRange:NSMakeRange(0, base.count)] isEqual:base]) {
                success = NO; message = @"La ruta de un archivo no pertenece a la carpeta de datos."; break;
            }
            NSString *relative = [[parts subarrayWithRange:NSMakeRange(base.count, parts.count - base.count)] componentsJoinedByString:@"/"];
            struct stat st;
            if (!safePath(relative) || lstat(url.fileSystemRepresentation, &st) != 0 || (!S_ISREG(st.st_mode) && !S_ISDIR(st.st_mode))) {
                success = NO; message = [NSString stringWithFormat:@"La copia contiene una ruta, enlace o archivo especial no compatible: %@", relative]; break;
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

+ (nullable NSDictionary<NSString *, id> *)inspectIPA:(NSURL *)source error:(NSError **)error {
    struct archive *a = archive_read_new();
    archive_read_support_format_zip(a);
    BOOL success = archive_read_open_filename(a, source.fileSystemRepresentation, 65536) == ARCHIVE_OK;
    NSString *reason = success ? @"La IPA está dañada o incompleta." : archiveMessage(a);
    NSString *const prefix = @"Payload/LiveContainer.app/";
    NSMutableSet<NSString *> *paths = [NSMutableSet set];
    NSMutableSet<NSString *> *plugins = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSDictionary *> *infos = [NSMutableDictionary dictionary];
    BOOL hostExecutable = NO, sideStoreExecutable = NO;
    uint64_t total = 0;
    NSUInteger count = 0;
    struct archive_entry *entry;
    int status = ARCHIVE_OK;
    while (success && (status = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char *raw = archive_entry_pathname(entry);
        NSString *path = raw ? [NSString stringWithUTF8String:raw] : nil;
        if (!safePath(path) || [paths containsObject:path.stringByStandardizingPath] ||
            archive_entry_symlink(entry) || archive_entry_hardlink(entry) ||
            (archive_entry_filetype(entry) != AE_IFREG && archive_entry_filetype(entry) != AE_IFDIR) ||
            archive_entry_size(entry) < 0 || ++count > 20000 ||
            (uint64_t)archive_entry_size(entry) > (1024ULL * 1024 * 1024) - total) {
            success = NO; reason = @"La IPA contiene rutas, enlaces o tamaños no seguros."; break;
        }
        [paths addObject:path.stringByStandardizingPath];
        if (archive_entry_filetype(entry) == AE_IFDIR) continue;
        int64_t entrySize = archive_entry_size(entry);
        BOOL isInfo = [path isEqualToString:[prefix stringByAppendingString:@"Info.plist"]] ||
            ([path hasPrefix:[prefix stringByAppendingString:@"PlugIns/"]] && [path hasSuffix:@".appex/Info.plist"]);
        if (isInfo && entrySize > 1024 * 1024) { success = NO; reason = @"Un Info.plist excede el límite permitido."; break; }
        NSMutableData *data = isInfo ? [NSMutableData dataWithCapacity:(NSUInteger)entrySize] : nil;
        char buffer[65536];
        la_ssize_t readCount;
        int64_t received = 0;
        while ((readCount = archive_read_data(a, buffer, sizeof(buffer))) > 0) {
            if ((uint64_t)readCount > (1024ULL * 1024 * 1024) - total) { success = NO; break; }
            total += (uint64_t)readCount;
            received += readCount;
            if (data) [data appendBytes:buffer length:(NSUInteger)readCount];
        }
        if (readCount < 0 || received != entrySize || !success) {
            success = NO; reason = @"La IPA contiene archivos truncados o dañados."; break;
        }
        if (data) {
            NSDictionary *info = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:nil];
            if (![info isKindOfClass:NSDictionary.class]) { success = NO; reason = @"La IPA contiene metadatos inválidos."; break; }
            infos[path] = info;
            if (![path isEqualToString:[prefix stringByAppendingString:@"Info.plist"]]) {
                NSString *name = [[path substringFromIndex:prefix.length + @"PlugIns/".length] componentsSeparatedByString:@"/"].firstObject;
                if (name) [plugins addObject:name];
            }
        }
        if ([path isEqualToString:[prefix stringByAppendingString:@"LiveContainer"]]) hostExecutable = YES;
        if ([path isEqualToString:[prefix stringByAppendingString:@"Frameworks/SideStoreApp.framework/SideStore"]]) sideStoreExecutable = YES;
    }
    if (success && status != ARCHIVE_EOF) { success = NO; reason = archiveMessage(a); }
    archive_read_free(a);
    NSString *rootInfo = [prefix stringByAppendingString:@"Info.plist"];
    NSDictionary *info = infos[rootInfo];
    NSString *bundle = info[@"CFBundleIdentifier"];
    NSString *version = info[@"CFBundleShortVersionString"];
    NSString *build = info[@"CFBundleVersion"];
    if (success && (![bundle isKindOfClass:NSString.class] || !bundle.length ||
                    ![version isKindOfClass:NSString.class] || !version.length ||
                    ![build isKindOfClass:NSString.class] || !build.length ||
                    !hostExecutable || !sideStoreExecutable ||
                    ![plugins containsObject:@"LiveProcess.appex"] ||
                    ![plugins containsObject:@"LiveWidgetExtension.appex"])) {
        success = NO; reason = @"No es una IPA completa de BloomBox con SideStore y extensiones.";
    }
    if (success) {
        for (NSString *plugin in plugins) {
            NSString *infoPath = [NSString stringWithFormat:@"%@PlugIns/%@/Info.plist", prefix, plugin];
            NSDictionary *pluginInfo = infos[infoPath];
            NSString *exe = pluginInfo[@"CFBundleExecutable"];
            NSString *identifier = pluginInfo[@"CFBundleIdentifier"];
            if (![exe isKindOfClass:NSString.class] || !exe.length ||
                ![identifier isKindOfClass:NSString.class] || ![identifier hasPrefix:bundle] ||
                ![paths containsObject:[NSString stringWithFormat:@"%@PlugIns/%@/%@", prefix, plugin, exe]]) {
                success = NO; reason = @"La IPA contiene una extensión incompleta o con otra identidad."; break;
            }
        }
    }
    if (!success) { if (error) *error = [NSError errorWithDomain:@"BloomBoxRAMIPA" code:1 userInfo:@{NSLocalizedDescriptionKey: reason}]; return nil; }
    return @{@"bundle": bundle, @"version": version, @"build": build,
             @"commit": [info[@"BloomBoxBuildCommit"] isKindOfClass:NSString.class] ? info[@"BloomBoxBuildCommit"] : @"",
             @"extensions": [plugins.allObjects sortedArrayUsingSelector:@selector(compare:)],
             @"groups": [info[@"ALTAppGroups"] isKindOfClass:NSArray.class] ? info[@"ALTAppGroups"] : @[]};
}

@end
