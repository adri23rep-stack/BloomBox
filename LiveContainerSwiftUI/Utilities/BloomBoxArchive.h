#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Streaming ZIP transport for data backups. Destinations must be fresh private directories.
@interface BloomBoxArchive : NSObject
+ (BOOL)packDirectory:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error NS_SWIFT_NAME(pack(source:destination:));
+ (BOOL)unpackFile:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error NS_SWIFT_NAME(unpack(source:destination:));
@end
NS_ASSUME_NONNULL_END
