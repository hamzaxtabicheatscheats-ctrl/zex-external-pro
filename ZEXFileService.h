#import <Foundation/Foundation.h>

@interface ZEXFileService : NSObject
@property (nonatomic, readonly) NSString *virtualRoot;
@property (nonatomic, readonly) BOOL ready;
+ (instancetype)shared;
- (void)createDirectories;
@end
