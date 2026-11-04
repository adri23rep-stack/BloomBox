#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Streaming ZIP transport for data backups. Destinations must be fresh private directories.
@interface BloomBoxArchive : NSObject
+ (BOOL)packDirectory:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error NS_SWIFT_NAME(pack(source:destination:));
+ (BOOL)unpackFile:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error NS_SWIFT_NAME(unpack(source:destination:));
/// Read/verify IPA entries without extraction. Does not authenticate its publisher.
+ (nullable NSDictionary<NSString *, id> *)inspectIPA:(NSURL *)source error:(NSError **)error NS_SWIFT_NAME(inspectIPA(_:));
@end
NS_ASSUME_NONNULL_END
