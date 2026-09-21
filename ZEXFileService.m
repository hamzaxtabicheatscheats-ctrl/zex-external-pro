#import "ZEXFileService.h"
#import "MCMFilzaIntegration.h"

@implementation ZEXFileService

+ (instancetype)shared {
    static ZEXFileService *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [ZEXFileService new]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    _virtualRoot = MCMFilzaVirtualRoot();
    _ready = (_virtualRoot.length > 0);
    return self;
}

- (void)createDirectories {
    if (!_virtualRoot.length) return;
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *dir in @[
        _virtualRoot,
        [_virtualRoot stringByAppendingPathComponent:@"[MHA-C2] App Data"],
        [_virtualRoot stringByAppendingPathComponent:@"[MHA-C12] System Data"],
    ]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

@end
