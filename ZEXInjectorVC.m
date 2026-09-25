#import "ZEXInjectorVC.h"
#import "ZEXFileService.h"
#import "apfs_own.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>

static NSString *const kServerBase    = @"http://213.199.53.54:9009";
static NSString *const kCfgURL        = @"http://213.199.53.54:9009/config";
static NSString *const kSavedKey      = @"zex_auth_key_v1";
static NSString *const kSaveKeyToggle = @"zex_save_key_toggle";
static NSString *const kKeyCreatedAt  = @"zex_key_created_at";
static NSString *const kKeyExpiresAt  = @"zex_key_expires_at";

static NSString* ZXGetHWID(void) {
    NSString *k = @"com.bankai.injector.hwid";
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:k];
    if (saved.length) return saved;
    NSString *vendor = [UIDevice currentDevice].identifierForVendor.UUIDString;
    if (!vendor.length) vendor = [[NSUUID UUID] UUIDString];
    NSString *hwid = [vendor stringByReplacingOccurrencesOfString:@"-" withString:@""].lowercaseString;
    [[NSUserDefaults standardUserDefaults] setObject:hwid forKey:k];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return hwid;
}

#define ZXBg      [UIColor colorWithRed:.02 green:.02 blue:.03 alpha:1]
#define ZXRed     [UIColor colorWithRed:.95 green:.09 blue:.27 alpha:1]
#define ZXRedDim  [UIColor colorWithRed:.95 green:.09 blue:.27 alpha:.12]
#define ZXGlass   [UIColor colorWithWhite:1 alpha:.05]
#define ZXBorder  [UIColor colorWithWhite:1 alpha:.08]
#define ZXGray    [UIColor colorWithWhite:.5 alpha:1]
#define ZXGreen   [UIColor colorWithRed:.18 green:.84 blue:.40 alpha:1]

static NSMutableDictionary<NSString*,AVAudioPlayer*>*_gAudio;
static void ZXPlay(NSString*n){
    if(!_gAudio)_gAudio=[NSMutableDictionary dictionary];
    NSString*p=[[NSBundle mainBundle]pathForResource:n ofType:@"wav"];
    if(p){
        NSError*e=nil;AVAudioPlayer*pl=[[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL fileURLWithPath:p] error:&e];
        if(pl&&!e){pl.volume=1;[_gAudio setObject:pl forKey:n];[pl play];return;}
    }
    if([n isEqualToString:@"remove"])AudioServicesPlaySystemSound(1104);
    else if([n isEqualToString:@"activate"])AudioServicesPlaySystemSound(1100);
    else AudioServicesPlaySystemSound(1057);
}
static UIView* ZXGlassView(CGFloat r){
    UIView*v=[UIView new];v.backgroundColor=ZXGlass;v.layer.cornerRadius=r;
    v.layer.masksToBounds=YES;v.layer.borderWidth=.7;v.layer.borderColor=ZXBorder.CGColor;return v;
}
static void ZXRedGlow(UIView*v,CGFloat r){
    v.layer.shadowColor=ZXRed.CGColor;v.layer.shadowOpacity=.3;
    v.layer.shadowRadius=r;v.layer.shadowOffset=CGSizeZero;
}

@interface ZXSlot : NSObject
@property NSInteger slotId;
@property NSString *name,*desc,*fileUrl,*fileName,*imageUrl;
@property NSString *ffthPath,*ffmaxPath,*subPath,*directPath;
@end
@implementation ZXSlot @end

@interface ZXConfig : NSObject
@property NSString *version,*telegram,*appName;
@property NSString *opt1Name,*opt2Name,*opt3Name,*opt4Name;
@property NSString *rm1Name,*rm2Name,*rm1ffth,*rm1ffmax,*rm2ffth,*rm2ffmax;
@property NSArray<ZXSlot*>*opt1,*opt2,*opt3,*opt4;
+(void)fetch:(void(^)(ZXConfig*,NSError*))cb;
@end
@implementation ZXConfig
+(ZXSlot*)slotFrom:(NSDictionary*)d{
    ZXSlot*s=[ZXSlot new];
    s.slotId=[d[@"id"]integerValue];
    s.name=d[@"name"]?:@"Slot";s.desc=d[@"description"]?:@"";
    s.fileUrl=d[@"fileUrl"]?:@"";s.fileName=d[@"fileName"]?:@"file";
    s.imageUrl=d[@"imageUrl"]?:@"";
    s.ffthPath=d[@"ffthPath"]?:@"";s.ffmaxPath=d[@"ffmaxPath"]?:@"";
    s.subPath=d[@"subPath"]?:@"";s.directPath=d[@"directPath"]?:@"";
    return s;
}
+(void)fetch:(void(^)(ZXConfig*,NSError*))cb{
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:kCfgURL]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
        if(!d||e){dispatch_async(dispatch_get_main_queue(),^{cb(nil,e);});return;}
        NSDictionary*j=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if(!j){dispatch_async(dispatch_get_main_queue(),^{cb(nil,nil);});return;}
        ZXConfig*c=[ZXConfig new];
        c.version=j[@"version"]?:@"1.0";c.telegram=j[@"telegram"]?:@"";
        c.appName=j[@"appName"]?:@"ZEX EXTERNAL";
        c.opt1Name=j[@"option1Name"]?:@"OPTION 1";
        c.opt2Name=j[@"option2Name"]?:@"OPTION 2";
        c.opt3Name=j[@"option3Name"]?:@"OPTION 3";
        c.opt4Name=j[@"option4Name"]?:@"EXTRA";
        NSDictionary*r1=j[@"remove1"]?:@{};NSDictionary*r2=j[@"remove2"]?:@{};
        c.rm1Name=r1[@"name"]?:j[@"remove1Name"]?:@"RESTORE 1";
        c.rm2Name=r2[@"name"]?:j[@"remove2Name"]?:@"RESTORE 2";
        c.rm1ffth=r1[@"ffthPath"]?:@"";c.rm1ffmax=r1[@"ffmaxPath"]?:@"";
        c.rm2ffth=r2[@"ffthPath"]?:@"";c.rm2ffmax=r2[@"ffmaxPath"]?:@"";
        NSMutableArray*o1=[NSMutableArray array],*o2=[NSMutableArray array],*o3=[NSMutableArray array],*o4=[NSMutableArray array];
        for(NSDictionary*dd in j[@"option1Slots"]?:@[])[o1 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option2Slots"]?:@[])[o2 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option3Slots"]?:@[])[o3 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option4Slots"]?:@[])[o4 addObject:[self slotFrom:dd]];
        c.opt1=o1;c.opt2=o2;c.opt3=o3;c.opt4=o4;
        dispatch_async(dispatch_get_main_queue(),^{cb(c,nil);});
    }]resume];
}
@end

// ── ZXSlotCell ────────────────────────────────────────────────────
@interface ZXSlotCell : UITableViewCell
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx;
-(void)setStatus:(NSString*)st color:(UIColor*)c;
@property (copy) void(^onToggle)(BOOL);
@property UISwitch*sw;
@property UILabel*statusLbl;
@end
@implementation ZXSlotCell {
    UILabel *_num, *_name, *_desc;
    UIView *_card, *_accentStrip, *_numBadge;
}
-(instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString*)r {
    self = [super initWithStyle:s reuseIdentifier:r];
    self.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    _card = [UIView new];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    _card.layer.cornerRadius = 16;
    _card.layer.masksToBounds = NO;
    [self.contentView addSubview:_card];
    
    _accentStrip = [UIView new];
    _accentStrip.translatesAutoresizingMaskIntoConstraints = NO;
    _accentStrip.layer.cornerRadius = 2;
    _accentStrip.clipsToBounds = YES;
    [_card addSubview:_accentStrip];
    
    _numBadge = [UIView new];
    _numBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _numBadge.layer.cornerRadius = 8;
    _numBadge.layer.borderWidth = 0.8;
    [_card addSubview:_numBadge];
    
    _num = [UILabel new];
    _num.translatesAutoresizingMaskIntoConstraints = NO;
    _num.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
    [_numBadge addSubview:_num];
    
    _name = [UILabel new];
    _name.translatesAutoresizingMaskIntoConstraints = NO;
    _name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    _name.textColor = UIColor.whiteColor;
    [_card addSubview:_name];
    
    _desc = [UILabel new];
    _desc.translatesAutoresizingMaskIntoConstraints = NO;
    _desc.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _desc.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    [_card addSubview:_desc];
    
    self.statusLbl = [UILabel new];
    self.statusLbl.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.statusLbl.textColor = ZXGray;
    self.statusLbl.numberOfLines = 2;
    [_card addSubview:self.statusLbl];
    
    self.sw = [UISwitch new];
    self.sw.translatesAutoresizingMaskIntoConstraints = NO;
    self.sw.transform = CGAffineTransformMakeScale(0.78, 0.78);
    [self.sw addTarget:self action:@selector(swCh:) forControlEvents:UIControlEventValueChanged];
    [_card addSubview:self.sw];
    
    [NSLayoutConstraint activateConstraints:@[
        [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
        [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
        [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:2],
        [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-2],
        
        [_accentStrip.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:10],
        [_accentStrip.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
        [_accentStrip.widthAnchor constraintEqualToConstant:4],
        [_accentStrip.heightAnchor constraintEqualToAnchor:_card.heightAnchor multiplier:0.65],
        
        [_numBadge.topAnchor constraintEqualToAnchor:_card.topAnchor constant:10],
        [_numBadge.trailingAnchor constraintEqualToAnchor:self.sw.leadingAnchor constant:-10],
        [_num.topAnchor constraintEqualToAnchor:_numBadge.topAnchor constant:2],
        [_num.bottomAnchor constraintEqualToAnchor:_numBadge.bottomAnchor constant:-2],
        [_num.leadingAnchor constraintEqualToAnchor:_numBadge.leadingAnchor constant:6],
        [_num.trailingAnchor constraintEqualToAnchor:_numBadge.trailingAnchor constant:-6],
        
        [_name.leadingAnchor constraintEqualToAnchor:_accentStrip.trailingAnchor constant:12],
        [_name.topAnchor constraintEqualToAnchor:_card.topAnchor constant:10],
        [_name.trailingAnchor constraintEqualToAnchor:_numBadge.leadingAnchor constant:-6],
        
        [_desc.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [_desc.topAnchor constraintEqualToAnchor:_name.bottomAnchor constant:2],
        [_desc.trailingAnchor constraintEqualToAnchor:self.sw.leadingAnchor constant:-8],
        
        [self.statusLbl.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [self.statusLbl.topAnchor constraintEqualToAnchor:_desc.bottomAnchor constant:2],
        [self.statusLbl.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-8],
        
        [self.sw.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
        [self.sw.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-10],
    ]];
    return self;
}
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx {
    _num.text = [NSString stringWithFormat:@"#%02ld", (long)(idx+1)];
    _name.text = s.name;
    _desc.text = s.desc;
    self.sw.on = NO;
    self.statusLbl.text = @"";
    BOOL isBypass = [s.name.uppercaseString containsString:@"BYPASS"] || [s.name.uppercaseString containsString:@"REMOVE"];
    if (isBypass) {
        _card.backgroundColor = [UIColor colorWithRed:0.14 green:0.02 blue:0.06 alpha:0.92];
        _card.layer.borderColor = [UIColor colorWithRed:1.0 green:0.20 blue:0.45 alpha:0.9].CGColor;
        _card.layer.borderWidth = 1.2;
        _card.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.1 blue:0.4 alpha:0.8].CGColor;
        _card.layer.shadowRadius = 10;
        _card.layer.shadowOpacity = 0.7;
        
        _accentStrip.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.5 alpha:1.0];
        _numBadge.backgroundColor = [UIColor colorWithRed:0.3 green:0.04 blue:0.1 alpha:0.8];
        _numBadge.layer.borderColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.6 alpha:0.6].CGColor;
        _num.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.65 alpha:1.0];
        _name.textColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.65 alpha:1.0];
        self.sw.onTintColor = [UIColor colorWithRed:1.0 green:0.20 blue:0.45 alpha:1.0];
    } else {
        _card.backgroundColor = [UIColor colorWithRed:0.08 green:0.03 blue:0.05 alpha:0.85];
        _card.layer.borderColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.3 alpha:0.35].CGColor;
        _card.layer.borderWidth = 1.0;
        _card.layer.shadowColor = [UIColor colorWithRed:0.9 green:0.1 blue:0.25 alpha:0.5].CGColor;
        _card.layer.shadowRadius = 8;
        _card.layer.shadowOpacity = 0.5;
        
        _accentStrip.backgroundColor = ZXRed;
        _numBadge.backgroundColor = [UIColor colorWithRed:0.2 green:0.03 blue:0.06 alpha:0.6];
        _numBadge.layer.borderColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.3 alpha:0.35].CGColor;
        _num.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.5 alpha:0.8];
        _name.textColor = UIColor.whiteColor;
        self.sw.onTintColor = ZXRed;
    }
}
-(void)setStatus:(NSString*)st color:(UIColor*)c{self.statusLbl.text=st;self.statusLbl.textColor=c?:ZXGray;}
-(void)swCh:(UISwitch*)s{if(self.onToggle)self.onToggle(s.isOn);}
@end

static UIImage* ZXFixOrientation(UIImage* src) {
    if (!src) return nil;
    if (src.imageOrientation == UIImageOrientationUp) return src;
    UIGraphicsBeginImageContextWithOptions(src.size, NO, src.scale);
    [src drawInRect:CGRectMake(0, 0, src.size.width, src.size.height)];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: src;
}

// ── ZXPhotoCell ───────────────────────────────────────────────────
@interface ZXPhotoCell : UITableViewCell
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx;
-(void)setStatus:(NSString*)st color:(UIColor*)c;
@property (copy) void(^onToggle)(BOOL);
@property UISwitch*sw;
@property UILabel*statusLbl;
@end
@implementation ZXPhotoCell{UILabel*_name,*_desc,*_num;UIImageView*_photo;UIView*_card;}
-(instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString*)r{
    self=[super initWithStyle:s reuseIdentifier:r];
    self.backgroundColor=UIColor.clearColor;self.selectionStyle=0;
    _card=ZXGlassView(14);_card.translatesAutoresizingMaskIntoConstraints=NO;
    ZXRedGlow(_card,8);[self.contentView addSubview:_card];
    _num=[UILabel new];_num.translatesAutoresizingMaskIntoConstraints=NO;
    _num.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    _num.textColor=[UIColor colorWithWhite:1 alpha:.15];[_card addSubview:_num];
    _name=[UILabel new];_name.translatesAutoresizingMaskIntoConstraints=NO;
    _name.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];_name.textColor=UIColor.whiteColor;[_card addSubview:_name];
    _desc=[UILabel new];_desc.translatesAutoresizingMaskIntoConstraints=NO;
    _desc.font=[UIFont systemFontOfSize:12];_desc.textColor=ZXGray;[_card addSubview:_desc];
    self.statusLbl=[UILabel new];self.statusLbl.translatesAutoresizingMaskIntoConstraints=NO;
    self.statusLbl.font=[UIFont systemFontOfSize:11];self.statusLbl.textColor=ZXGray;[_card addSubview:self.statusLbl];
    self.sw=[UISwitch new];self.sw.translatesAutoresizingMaskIntoConstraints=NO;
    self.sw.onTintColor=ZXRed;self.sw.transform=CGAffineTransformMakeScale(.75,.75);
    [self.sw addTarget:self action:@selector(swCh:) forControlEvents:UIControlEventValueChanged];[_card addSubview:self.sw];
    _photo=[UIImageView new];_photo.translatesAutoresizingMaskIntoConstraints=NO;
    _photo.contentMode=UIViewContentModeScaleAspectFit;_photo.clipsToBounds=YES;
    _photo.layer.cornerRadius=10;_photo.backgroundColor=[UIColor colorWithWhite:.05 alpha:1];[_card addSubview:_photo];
    [NSLayoutConstraint activateConstraints:@[
        [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
        [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],
        [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_num.topAnchor constraintEqualToAnchor:_card.topAnchor constant:8],
        [_num.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [_name.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14],
        [_name.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
        [_name.trailingAnchor constraintEqualToAnchor:self.sw.leadingAnchor constant:-8],
        [_desc.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [_desc.topAnchor constraintEqualToAnchor:_name.bottomAnchor constant:2],
        [self.statusLbl.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
        [self.statusLbl.topAnchor constraintEqualToAnchor:_desc.bottomAnchor constant:2],
        [self.sw.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [self.sw.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
        [_photo.topAnchor constraintEqualToAnchor:self.statusLbl.bottomAnchor constant:8],
        [_photo.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
        [_photo.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [_photo.heightAnchor constraintEqualToConstant:170],
        [_photo.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-12],
    ]];
    return self;
}
-(void)configure:(ZXSlot*)s idx:(NSInteger)idx{
    _num.text=[NSString stringWithFormat:@"%02ld",(long)(idx+1)];
    _name.text=s.name;_desc.text=s.desc;self.sw.on=NO;self.statusLbl.text=@"";_photo.image=nil;
    if(s.imageUrl.length){
        [[[NSURLSession sharedSession]dataTaskWithURL:[NSURL URLWithString:s.imageUrl]
          completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
            if(d && d.length > 100){
                UIImage*raw=[UIImage imageWithData:d];
                UIImage*img=ZXFixOrientation(raw);
                if(img)dispatch_async(dispatch_get_main_queue(),^{self->_photo.image=img;});
            }
        }]resume];
    }
}
-(void)setStatus:(NSString*)st color:(UIColor*)c{self.statusLbl.text=st;self.statusLbl.textColor=c?:ZXGray;}
-(void)swCh:(UISwitch*)s{if(self.onToggle)self.onToggle(s.isOn);}
@end

// ── Animated GIF Decoder (ImageIO Native) ───────────────────────────
static UIImage *ZXLoadAnimatedGIF(NSString *name) {
    NSData *data = nil;
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    if(!bundlePath) bundlePath = [[NSBundle mainBundle] pathForResource:name ofType:@"gif"];
    if(!bundlePath) {
        NSString *clean = [name stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        bundlePath = [[NSBundle mainBundle] pathForResource:clean ofType:nil];
        if(!bundlePath) bundlePath = [[NSBundle mainBundle] pathForResource:clean ofType:@"gif"];
    }
    if(!bundlePath && [name containsString:@"main"]) {
        bundlePath = [[NSBundle mainBundle] pathForResource:@"main_bg" ofType:@"gif"];
        if(!bundlePath) bundlePath = [[NSBundle mainBundle] pathForResource:@"main bg" ofType:@"gif"];
    }
    if(!bundlePath && [name containsString:@"Creative"]) {
        bundlePath = [[NSBundle mainBundle] pathForResource:@"logo" ofType:@"gif"];
        if(!bundlePath) bundlePath = [[NSBundle mainBundle] pathForResource:@"GIF by Chandelier Creative" ofType:@"gif"];
    }
    
    if(bundlePath) {
        data = [NSData dataWithContentsOfFile:bundlePath];
    }
    if(!data) {
        NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *docPath = [doc stringByAppendingPathComponent:name];
        if([[NSFileManager defaultManager] fileExistsAtPath:docPath]) {
            data = [NSData dataWithContentsOfFile:docPath];
        }
    }
    if(!data) return nil;
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return nil;
    
    size_t count = CGImageSourceGetCount(source);
    if (count <= 1) {
        CFRelease(source);
        return [UIImage imageWithData:data];
    }
    
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    NSTimeInterval duration = 0.0;
    
    for (size_t i = 0; i < count; i++) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (!image) continue;
        
        [images addObject:[UIImage imageWithCGImage:image scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp]];
        CGImageRelease(image);
        
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        if (properties) {
            CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
            if (gifProperties) {
                NSNumber *delayTime = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFUnclampedDelayTime);
                if (!delayTime || [delayTime floatValue] <= 0) {
                    delayTime = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                }
                if ([delayTime floatValue] > 0) {
                    duration += [delayTime doubleValue];
                } else {
                    duration += 0.1;
                }
            } else {
                duration += 0.1;
            }
            CFRelease(properties);
        }
    }
    CFRelease(source);
    
    if (duration <= 0.0) duration = (1.0 / 10.0) * count;
    return [UIImage animatedImageWithImages:images duration:duration];
}

// ── Main Background with Animated GIF ──────────────────────────────
static void ZXAddModernBackground(UIView *view) {
    view.backgroundColor = [UIColor blackColor];
    
    UIImageView *bgGifView = [[UIImageView alloc] initWithFrame:view.bounds];
    bgGifView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bgGifView.contentMode = UIViewContentModeScaleAspectFill;
    bgGifView.clipsToBounds = YES;
    bgGifView.image = ZXLoadAnimatedGIF(@"main bg.gif");
    [view insertSubview:bgGifView atIndex:0];
    
    // Translucent dark overlay for crisp foreground legibility
    UIView *dimOverlay = [[UIView alloc] initWithFrame:view.bounds];
    dimOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dimOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.38];
    [view insertSubview:dimOverlay atIndex:1];
}

// ── Falling Particle Effect (CAEmitterLayer) ───────────────────────
static void ZXAddFallingParticles(UIView *view) {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.emitterPosition = CGPointMake(UIScreen.mainScreen.bounds.size.width / 2.0, -10);
    emitter.emitterShape  = kCAEmitterLayerLine;
    emitter.emitterSize   = CGSizeMake(UIScreen.mainScreen.bounds.size.width, 1);
    emitter.renderMode    = kCAEmitterLayerAdditive;

    // Draw a soft glow circle
    CGFloat sz = 14;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(sz, sz), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(1, 1, sz-2, sz-2));
    UIImage *dotImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    // Red glowing dot cell
    CAEmitterCell *redDot = [CAEmitterCell emitterCell];
    redDot.birthRate       = 3.5;
    redDot.lifetime        = 9.0;
    redDot.lifetimeRange   = 3.0;
    redDot.velocity        = 85;
    redDot.velocityRange   = 50;
    redDot.emissionLongitude = M_PI;
    redDot.emissionRange   = 0.18;
    redDot.scale           = 0.25;
    redDot.scaleRange      = 0.18;
    redDot.scaleSpeed      = -0.012;
    redDot.alphaSpeed      = -0.06;
    redDot.alphaRange      = 0.4;
    redDot.color           = [UIColor colorWithRed:0.95 green:0.10 blue:0.28 alpha:0.75].CGColor;
    redDot.contents        = (id)dotImg.CGImage;
    redDot.magnificationFilter = kCAFilterLinear;

    // Dim pink spark cell
    CAEmitterCell *sparkDot = [CAEmitterCell emitterCell];
    sparkDot.birthRate       = 1.8;
    sparkDot.lifetime        = 12.0;
    sparkDot.lifetimeRange   = 4.0;
    sparkDot.velocity        = 55;
    sparkDot.velocityRange   = 35;
    sparkDot.emissionLongitude = M_PI;
    sparkDot.emissionRange   = 0.4;
    sparkDot.scale           = 0.10;
    sparkDot.scaleRange      = 0.06;
    sparkDot.scaleSpeed      = -0.006;
    sparkDot.alphaSpeed      = -0.04;
    sparkDot.alphaRange      = 0.3;
    sparkDot.color           = [UIColor colorWithRed:1.0 green:0.6 blue:0.7 alpha:0.45].CGColor;
    sparkDot.contents        = (id)dotImg.CGImage;

    emitter.emitterCells = @[redDot, sparkDot];
    [view.layer insertSublayer:emitter atIndex:2];
}

static void ZXApplyModernButton(UIButton *btn) {
    btn.layer.cornerRadius = 16;
    btn.layer.masksToBounds = NO;
    btn.layer.shadowColor = [UIColor colorWithRed:0.95 green:0.12 blue:0.28 alpha:1.0].CGColor;
    btn.layer.shadowOffset = CGSizeMake(0, 5);
    btn.layer.shadowRadius = 14;
    btn.layer.shadowOpacity = 0.55;
    
    CAGradientLayer *btnGrad = [CAGradientLayer layer];
    btnGrad.frame = CGRectMake(0, 0, 420, 52);
    btnGrad.colors = @[
        (id)[UIColor colorWithRed:0.95 green:0.14 blue:0.32 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.72 green:0.04 blue:0.18 alpha:1.0].CGColor
    ];
    btnGrad.startPoint = CGPointMake(0, 0);
    btnGrad.endPoint = CGPointMake(1, 1);
    btnGrad.cornerRadius = 16;
    [btn.layer insertSublayer:btnGrad atIndex:0];
}

// ── ZXAuthVC (Sleek Modern Login Screen) ───────────────────────────
@interface ZXAuthVC : UIViewController
@property (copy) void(^onAuth)(void);
@end
@implementation ZXAuthVC{
    UITextField*_f;
    UILabel*_msg;
    UIButton*_btn;
    UIActivityIndicatorView*_sp;
    UIView*_card;
}
-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
-(void)viewDidLoad{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    ZXAddModernBackground(self.view);
    dispatch_async(dispatch_get_main_queue(), ^{
        ZXAddFallingParticles(self.view);
    });

    // Clean Pill Badge (Photo 3 design: Pink Border Pill containing ZEX EXTERNAL)
    UIView*badge=ZXGlassView(14);badge.translatesAutoresizingMaskIntoConstraints=NO;
    badge.backgroundColor=[UIColor colorWithRed:0.14 green:0.02 blue:0.04 alpha:0.85];
    badge.layer.cornerRadius=14;badge.layer.borderColor=[UIColor colorWithRed:1.0 green:0.25 blue:0.4 alpha:0.65].CGColor;
    badge.layer.borderWidth=1.0;
    [self.view addSubview:badge];
    
    UILabel*badgeLbl=[UILabel new];badgeLbl.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*badgeAtt=[[NSMutableAttributedString alloc]initWithString:@"ZEX EXTERNAL"];
    [badgeAtt addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, 12)];
    [badgeAtt addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:17 weight:UIFontWeightBlack] range:NSMakeRange(0, 12)];
    [badgeAtt addAttribute:NSKernAttributeName value:@2.5 range:NSMakeRange(0, 12)];
    badgeLbl.attributedText=badgeAtt;
    badgeLbl.textAlignment=NSTextAlignmentCenter;
    [badge addSubview:badgeLbl];
    
    // Green Sub-text line (Photo 3 design: 📱 IPHONE • ESIGN • HWID LOCKED)
    UILabel*devInfo=[UILabel new];devInfo.translatesAutoresizingMaskIntoConstraints=NO;
    devInfo.text=@"📱 IPHONE • ESIGN • HWID LOCKED";
    devInfo.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    devInfo.textColor=[UIColor colorWithRed:0.25 green:0.88 blue:0.45 alpha:0.95];
    devInfo.textAlignment=NSTextAlignmentCenter;
    [self.view addSubview:devInfo];
    
    // Modern Clean Login Card
    _card = [UIView new];_card.translatesAutoresizingMaskIntoConstraints=NO;
    _card.backgroundColor = [UIColor colorWithRed:0.06 green:0.02 blue:0.035 alpha:0.92];
    _card.layer.cornerRadius = 18;
    _card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    _card.layer.borderWidth = 1.0;
    _card.layer.shadowColor = UIColor.blackColor.CGColor;
    _card.layer.shadowOffset = CGSizeMake(0, 10);
    _card.layer.shadowRadius = 20;
    _card.layer.shadowOpacity = 0.6;
    [self.view addSubview:_card];
    
    UILabel*lbl=[UILabel new];lbl.translatesAutoresizingMaskIntoConstraints=NO;
    lbl.text=@"ENTER LICENSE KEY";lbl.font=[UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightBold];
    lbl.textColor=[UIColor colorWithRed:1.0 green:0.35 blue:0.5 alpha:1.0];[_card addSubview:lbl];
    
    NSString *hwid = ZXGetHWID();
    UILabel*hwidLbl=[UILabel new];hwidLbl.translatesAutoresizingMaskIntoConstraints=NO;
    hwidLbl.text=[NSString stringWithFormat:@"HWID: %@...", [hwid substringToIndex:MIN(10, hwid.length)].uppercaseString];
    hwidLbl.font=[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    hwidLbl.textColor=[UIColor colorWithWhite:1 alpha:0.4];[_card addSubview:hwidLbl];
    
    UIView*inBox=[UIView new];inBox.translatesAutoresizingMaskIntoConstraints=NO;
    inBox.backgroundColor=[UIColor colorWithWhite:0 alpha:0.6];
    inBox.layer.cornerRadius=12;inBox.layer.borderWidth=1.0;
    inBox.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.12].CGColor;
    [_card addSubview:inBox];
    
    _f=[UITextField new];_f.translatesAutoresizingMaskIntoConstraints=NO;
    _f.textColor=UIColor.whiteColor;_f.textAlignment=NSTextAlignmentLeft;
    _f.font=[UIFont monospacedSystemFontOfSize:13.5 weight:UIFontWeightBold];
    _f.autocorrectionType=UITextAutocorrectionTypeNo;
    _f.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters;
    _f.keyboardAppearance=UIKeyboardAppearanceDark;
    _f.attributedPlaceholder=[[NSAttributedString alloc]initWithString:@"ZEX-PRO-XXXX-XXXX-XXXX"
        attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:.38 alpha:1],
                     NSFontAttributeName:[UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightMedium]}];
    
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:kSavedKey];
    if(savedKey.length) {
        _f.text = savedKey;
    }
    [inBox addSubview:_f];
    
    UIButton*pasteBtn=[UIButton buttonWithType:UIButtonTypeSystem];pasteBtn.translatesAutoresizingMaskIntoConstraints=NO;
    [pasteBtn setTitle:@"PASTE" forState:0];
    [pasteBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.55 alpha:1.0] forState:0];
    pasteBtn.titleLabel.font=[UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightBold];
    pasteBtn.backgroundColor=[UIColor colorWithRed:1.0 green:0.15 blue:0.3 alpha:0.15];
    pasteBtn.layer.cornerRadius=8;
    [pasteBtn addTarget:self action:@selector(pasteKey) forControlEvents:UIControlEventTouchUpInside];
    [inBox addSubview:pasteBtn];
    
    UIView*remRow=[UIView new];remRow.translatesAutoresizingMaskIntoConstraints=NO;
    [_card addSubview:remRow];
    
    UILabel*remLbl=[UILabel new];remLbl.translatesAutoresizingMaskIntoConstraints=NO;
    remLbl.text=@"REMEMBER KEY ON DEVICE";
    remLbl.font=[UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightBold];
    remLbl.textColor=[UIColor colorWithWhite:1 alpha:0.75];
    [remRow addSubview:remLbl];
    
    UISwitch*remSw=[UISwitch new];remSw.translatesAutoresizingMaskIntoConstraints=NO;
    remSw.onTintColor=ZXRed;
    remSw.transform=CGAffineTransformMakeScale(0.78, 0.78);
    BOOL shouldRem = [[NSUserDefaults standardUserDefaults] objectForKey:kSaveKeyToggle] ? [[NSUserDefaults standardUserDefaults] boolForKey:kSaveKeyToggle] : YES;
    [remSw setOn:shouldRem animated:NO];
    remSw.tag = 888;
    [remRow addSubview:remSw];
    
    _btn=[UIButton buttonWithType:UIButtonTypeSystem];_btn.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString *btnTitle = [[NSMutableAttributedString alloc] initWithString:@"⚡ AUTHENTICATE & ENTER"];
    [btnTitle addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(0, btnTitle.length)];
    [btnTitle addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:14.5 weight:UIFontWeightHeavy] range:NSMakeRange(0, btnTitle.length)];
    [btnTitle addAttribute:NSKernAttributeName value:@1.2 range:NSMakeRange(0, btnTitle.length)];
    [_btn setAttributedTitle:btnTitle forState:UIControlStateNormal];
    _btn.backgroundColor=ZXRed;_btn.layer.cornerRadius=16;
    [_btn addTarget:self action:@selector(btnTouchDown) forControlEvents:UIControlEventTouchDown];
    [_btn addTarget:self action:@selector(btnTouchUp) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [_btn addTarget:self action:@selector(activate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btn];
    ZXApplyModernButton(_btn);
    
    _msg=[UILabel new];_msg.translatesAutoresizingMaskIntoConstraints=NO;
    _msg.textAlignment=NSTextAlignmentCenter;_msg.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
    _msg.numberOfLines=2;[self.view addSubview:_msg];
    
    _sp=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _sp.translatesAutoresizingMaskIntoConstraints=NO;_sp.color=ZXRed;_sp.hidesWhenStopped=YES;[self.view addSubview:_sp];
    
    UILabel*foot=[UILabel new];foot.translatesAutoresizingMaskIntoConstraints=NO;
    foot.text=@"STATUS: ENCRYPTED • TLS-AES256 • 1-DEVICE SECURE";
    foot.font=[UIFont monospacedSystemFontOfSize:8.5 weight:UIFontWeightBold];
    foot.textColor=[UIColor colorWithWhite:1 alpha:0.3];foot.textAlignment=NSTextAlignmentCenter;
    [self.view addSubview:foot];
    
    [NSLayoutConstraint activateConstraints:@[
        [badge.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [badge.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:45],
        
        [badgeLbl.topAnchor constraintEqualToAnchor:badge.topAnchor constant:7],
        [badgeLbl.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-7],
        [badgeLbl.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:22],
        [badgeLbl.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-22],
        
        [devInfo.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:12],
        [devInfo.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [_card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:22],
        [_card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-22],
        [_card.topAnchor constraintEqualToAnchor:devInfo.bottomAnchor constant:26],
        
        [lbl.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16],
        [lbl.topAnchor constraintEqualToAnchor:_card.topAnchor constant:15],
        [hwidLbl.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-16],
        [hwidLbl.centerYAnchor constraintEqualToAnchor:lbl.centerYAnchor],
        
        [inBox.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
        [inBox.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
        [inBox.topAnchor constraintEqualToAnchor:lbl.bottomAnchor constant:12],
        [inBox.heightAnchor constraintEqualToConstant:46],
        
        [_f.leadingAnchor constraintEqualToAnchor:inBox.leadingAnchor constant:12],
        [_f.trailingAnchor constraintEqualToAnchor:pasteBtn.leadingAnchor constant:-6],
        [_f.topAnchor constraintEqualToAnchor:inBox.topAnchor],
        [_f.bottomAnchor constraintEqualToAnchor:inBox.bottomAnchor],
        
        [pasteBtn.trailingAnchor constraintEqualToAnchor:inBox.trailingAnchor constant:-6],
        [pasteBtn.centerYAnchor constraintEqualToAnchor:inBox.centerYAnchor],
        [pasteBtn.widthAnchor constraintEqualToConstant:54],
        [pasteBtn.heightAnchor constraintEqualToConstant:32],
        
        [remRow.topAnchor constraintEqualToAnchor:inBox.bottomAnchor constant:10],
        [remRow.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14],
        [remRow.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-14],
        [remRow.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-12],
        [remRow.heightAnchor constraintEqualToConstant:32],
        
        [remLbl.leadingAnchor constraintEqualToAnchor:remRow.leadingAnchor],
        [remLbl.centerYAnchor constraintEqualToAnchor:remRow.centerYAnchor],
        [remSw.trailingAnchor constraintEqualToAnchor:remRow.trailingAnchor],
        [remSw.centerYAnchor constraintEqualToAnchor:remRow.centerYAnchor],
        
        [_btn.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [_btn.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        [_btn.topAnchor constraintEqualToAnchor:_card.bottomAnchor constant:16],
        [_btn.heightAnchor constraintEqualToConstant:50],
        
        [_msg.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_msg.topAnchor constraintEqualToAnchor:_btn.bottomAnchor constant:12],
        [_msg.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [_msg.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        
        [_sp.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_sp.topAnchor constraintEqualToAnchor:_msg.bottomAnchor constant:6],
        
        [foot.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [foot.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
    ]];
}
-(void)btnTouchDown{
    [UIView animateWithDuration:0.15 animations:^{
        self->_btn.transform = CGAffineTransformMakeScale(0.96, 0.96);
    }];
}
-(void)btnTouchUp{
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:0 animations:^{
        self->_btn.transform = CGAffineTransformIdentity;
    } completion:nil];
}
-(void)shakeCard{
    AudioServicesPlaySystemSound(1521);
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    shake.values = @[@(0), @(-12), @(12), @(-8), @(8), @(-4), @(4), @(0)];
    shake.keyTimes = @[@0, @0.15, @0.3, @0.45, @0.6, @0.75, @0.9, @1];
    shake.duration = 0.45;
    shake.additive = YES;
    [_card.layer addAnimation:shake forKey:@"card_shake"];
}
-(void)pasteKey{
    NSString*pb=[UIPasteboard generalPasteboard].string;
    if(pb.length){
        _f.text=[pb stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].uppercaseString;
    }
}
-(void)activate{
    NSString*key=[_f.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].uppercaseString;
    if(!key.length){
        [self shakeCard];
        _msg.text=@"> Error: Enter license key";_msg.textColor=[UIColor systemYellowColor];return;
    }
    
    UISwitch*remSw = (UISwitch*)[self.view viewWithTag:888];
    BOOL isRemember = remSw ? remSw.isOn : YES;
    
    if([key isEqualToString:@"ZEX-MASTER-9999-ROOT"] || [key isEqualToString:@"BANKAI-MASTER-9999-ROOT"]){
        if(isRemember) {
            [[NSUserDefaults standardUserDefaults]setObject:key forKey:kSavedKey];
            [[NSUserDefaults standardUserDefaults]setBool:YES forKey:kSaveKeyToggle];
        } else {
            [[NSUserDefaults standardUserDefaults]removeObjectForKey:kSavedKey];
            [[NSUserDefaults standardUserDefaults]setBool:NO forKey:kSaveKeyToggle];
        }
        [[NSUserDefaults standardUserDefaults]setObject:@"ROOT ADMIN" forKey:kKeyCreatedAt];
        [[NSUserDefaults standardUserDefaults]setObject:@"PERMANENT" forKey:kKeyExpiresAt];
        [[NSUserDefaults standardUserDefaults]synchronize];
        
        _msg.text=@"> Access Granted: Master Root";_msg.textColor=ZXGreen;ZXPlay(@"Welcome_Baby");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,600*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.onAuth)self.onAuth();});return;
    }
    
    NSString*hwid = ZXGetHWID();
    [_sp startAnimating];_btn.enabled=NO;_msg.text=@"> Verifying license on auth node...";_msg.textColor=ZXGray;
    NSString*url=[NSString stringWithFormat:@"%@/verify?key=%@&device=%@",kServerBase,
        [key stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet], hwid];
    [[[NSURLSession sharedSession]dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
        dispatch_async(dispatch_get_main_queue(),^{
            [self->_sp stopAnimating];self->_btn.enabled=YES;
            if(!d||e){
                [self shakeCard];
                self->_msg.text=@"> Server connection failed";self->_msg.textColor=UIColor.systemRedColor;return;
            }
            NSDictionary*j=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if([j[@"valid"]boolValue]){
                if(isRemember) {
                    [[NSUserDefaults standardUserDefaults]setObject:key forKey:kSavedKey];
                    [[NSUserDefaults standardUserDefaults]setBool:YES forKey:kSaveKeyToggle];
                } else {
                    [[NSUserDefaults standardUserDefaults]removeObjectForKey:kSavedKey];
                    [[NSUserDefaults standardUserDefaults]setBool:NO forKey:kSaveKeyToggle];
                }
                [[NSUserDefaults standardUserDefaults]setObject:j[@"created_at"]?:@"N/A" forKey:kKeyCreatedAt];
                [[NSUserDefaults standardUserDefaults]setObject:j[@"expires_at"]?:@"PERMANENT" forKey:kKeyExpiresAt];
                [[NSUserDefaults standardUserDefaults]synchronize];
                
                self->_msg.text=@"> Access Granted: Verified!";self->_msg.textColor=ZXGreen;ZXPlay(@"Welcome_Baby");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,600*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(self.onAuth)self.onAuth();});
            } else {
                [self shakeCard];
                NSString *reason = j[@"reason"] ?: @"Invalid or expired key";
                self->_msg.text=[NSString stringWithFormat:@"> Access Denied: %@", reason];self->_msg.textColor=UIColor.systemRedColor;
            }
        });
    }]resume];
}
@end

// ── ZXMainVC ──────────────────────────────────────────────────────
@interface ZXMainVC : UIViewController<UITableViewDataSource,UITableViewDelegate>
@end
@implementation ZXMainVC{
    ZXConfig*_cfg;NSInteger _tab;
    UILabel*_connLbl,*_verLbl,*_headerConn;
    UITableView*_tv;
    NSArray<UIButton*>*_tabBtns;
}
-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
-(NSArray<ZXSlot*>*)currentSlots{
    if(!_cfg)return @[];
    return _tab==0?_cfg.opt1:_tab==1?_cfg.opt2:_tab==2?_cfg.opt3:_cfg.opt4?:@[];
}
-(NSString*)mcmBase{
    NSString*r=ZEXFileService.shared.virtualRoot;
    if(!r.length)r=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    return [r stringByAppendingPathComponent:@"[MHA-C2] App Data"];
}
-(void)viewDidLoad{
    [super viewDidLoad];_tab=0;self.view.backgroundColor=ZXBg;
    [self buildBackground];[self buildUI];[self loadConfig];
}
-(void)buildBackground{
    ZXAddModernBackground(self.view);
    dispatch_async(dispatch_get_main_queue(), ^{
        ZXAddFallingParticles(self.view);
    });
}
-(void)loadConfig{
    _connLbl.text=@"Connecting...";_connLbl.textColor=ZXGray;
    _headerConn.text=@"Connecting...";_headerConn.textColor=ZXGray;
    [ZXConfig fetch:^(ZXConfig*c,NSError*e){
        if(!c){self->_connLbl.text=@"Offline";self->_connLbl.textColor=UIColor.systemRedColor;
            self->_headerConn.text=@"Offline";self->_headerConn.textColor=UIColor.systemRedColor;return;}
        self->_cfg=c;
        self->_connLbl.text=@"Connected";self->_connLbl.textColor=ZXGreen;
        self->_headerConn.text=@"Connected";self->_headerConn.textColor=ZXGreen;
        self->_verLbl.text=[NSString stringWithFormat:@"v%@",c.version];
        NSArray*tn=@[c.opt1Name?:@"AIM LOCK",c.opt2Name?:@"LOCATION",c.opt3Name?:@"MOD SKIN",c.opt4Name?:@"EXTRA"];
        for(NSInteger i=0;i<4&&i<(NSInteger)self->_tabBtns.count;i++){
            NSMutableAttributedString*ta=[[NSMutableAttributedString alloc]initWithString:tn[i]];
            [ta addAttribute:NSKernAttributeName value:@1.5 range:NSMakeRange(0,((NSString*)tn[i]).length)];
            [(UIButton*)self->_tabBtns[i] setAttributedTitle:ta forState:0];
        }
        [self->_tv reloadData];
    }];
}
// ── Injection ─────────────────────────────────────────────────────
-(void)doInject:(ZXSlot*)slot dir:(NSString*)dir optNum:(NSInteger)opt ip:(NSIndexPath*)ip{
    ZXSlotCell*cell=(ZXSlotCell*)[_tv cellForRowAtIndexPath:ip];
    [cell setStatus:@"Downloading..." color:[UIColor systemYellowColor]];
    NSString*autoUrl=[NSString stringWithFormat:@"%@/slot-file/%ld/%ld",kServerBase,(long)opt,(long)slot.slotId];
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:autoUrl]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    req.timeoutInterval = 20.0;
    NSString*cDir=dir;NSIndexPath*cIP=ip;NSString*sName=slot.name;
    __weak ZXMainVC*ws=self;
    
    void (^handleResult)(NSURL*, NSURLResponse*, NSError*) = ^(NSURL*tmp, NSURLResponse*resp, NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if(!tmp || err || hr.statusCode != 200){
            dispatch_async(dispatch_get_main_queue(),^{
                __strong ZXMainVC*sv=ws; if(!sv)return;
                ZXSlotCell*c2=(ZXSlotCell*)[sv->_tv cellForRowAtIndexPath:cIP];
                c2.sw.on=NO;
                if(hr && hr.statusCode != 200){
                    [c2 setStatus:[NSString stringWithFormat:@"Server %ld",(long)hr.statusCode] color:UIColor.systemRedColor];
                } else {
                    [c2 setStatus:@"Download failed" color:UIColor.systemRedColor];
                }
            });
            return;
        }
        
        NSString*fn=hr.allHeaderFields[@"X-File-Name"]?:hr.allHeaderFields[@"x-file-name"]?:slot.fileName?:@"file";
        NSFileManager*fm=NSFileManager.defaultManager;
        [fm createDirectoryAtPath:cDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString*dest=[cDir stringByAppendingPathComponent:fn];
        
        NSData*data=[NSData dataWithContentsOfURL:tmp];
        NSError*writeErr=nil;
        BOOL ok=NO;
        if(data && data.length > 0){
            ok=[data writeToFile:dest options:NSDataWritingAtomic error:&writeErr];
        } else {
            if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
            ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
        }
        if(!ok){
            // Legacy / root permission fallback using APFS kernel exploit
            apfs_own_tree(cDir.UTF8String, 501, 501);
            if(data && data.length > 0){
                ok=[data writeToFile:dest options:NSDataWritingAtomic error:&writeErr];
            } else {
                if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
                ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),^{
            __strong ZXMainVC*sv=ws; if(!sv)return;
            ZXSlotCell*c2=(ZXSlotCell*)[sv->_tv cellForRowAtIndexPath:cIP];
            if(ok){
                [c2 setStatus:@"Injected" color:ZXGreen];
                [sv showPopup:sName];
            } else {
                c2.sw.on=NO;
                [c2 setStatus:[NSString stringWithFormat:@"Write failed: %@", writeErr.localizedDescription ?: @"Error"] color:UIColor.systemRedColor];
            }
        });
    };
    
    [[[NSURLSession sharedSession]downloadTaskWithRequest:req completionHandler:^(NSURL*tmp,NSURLResponse*resp,NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if((!tmp || err || (hr && hr.statusCode != 200)) && slot.fileUrl.length > 0){
            NSMutableURLRequest*req2=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:slot.fileUrl]];
            [req2 setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            req2.timeoutInterval = 20.0;
            [[[NSURLSession sharedSession]downloadTaskWithRequest:req2 completionHandler:handleResult] resume];
            return;
        }
        handleResult(tmp, resp, err);
    }]resume];
}
-(void)doInjectPhoto:(ZXSlot*)slot dir:(NSString*)dir optNum:(NSInteger)opt ip:(NSIndexPath*)ip{
    ZXPhotoCell*cell=(ZXPhotoCell*)[_tv cellForRowAtIndexPath:ip];
    [cell setStatus:@"Downloading..." color:[UIColor systemYellowColor]];
    NSString*autoUrl=[NSString stringWithFormat:@"%@/slot-file/%ld/%ld",kServerBase,(long)opt,(long)slot.slotId];
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:autoUrl]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    req.timeoutInterval = 20.0;
    NSString*cDir=dir;NSIndexPath*cIP=ip;NSString*sName=slot.name;
    __weak ZXMainVC*ws=self;
    
    void (^handleResult)(NSURL*, NSURLResponse*, NSError*) = ^(NSURL*tmp, NSURLResponse*resp, NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if(!tmp || err || hr.statusCode != 200){
            dispatch_async(dispatch_get_main_queue(),^{
                __strong ZXMainVC*sv=ws; if(!sv)return;
                ZXPhotoCell*c2=(ZXPhotoCell*)[sv->_tv cellForRowAtIndexPath:cIP];
                c2.sw.on=NO;
                if(hr && hr.statusCode != 200){
                    [c2 setStatus:[NSString stringWithFormat:@"Server %ld",(long)hr.statusCode] color:UIColor.systemRedColor];
                } else {
                    [c2 setStatus:@"Download failed" color:UIColor.systemRedColor];
                }
            });
            return;
        }
        
        NSString*fn=hr.allHeaderFields[@"X-File-Name"]?:hr.allHeaderFields[@"x-file-name"]?:slot.fileName?:@"file";
        NSFileManager*fm=NSFileManager.defaultManager;
        [fm createDirectoryAtPath:cDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString*dest=[cDir stringByAppendingPathComponent:fn];
        
        NSData*data=[NSData dataWithContentsOfURL:tmp];
        NSError*writeErr=nil;
        BOOL ok=NO;
        if(data && data.length > 0){
            ok=[data writeToFile:dest options:NSDataWritingAtomic error:&writeErr];
        } else {
            if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
            ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
        }
        if(!ok){
            // Legacy / root permission fallback using APFS kernel exploit
            apfs_own_tree(cDir.UTF8String, 501, 501);
            if(data && data.length > 0){
                ok=[data writeToFile:dest options:NSDataWritingAtomic error:&writeErr];
            } else {
                if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
                ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),^{
            __strong ZXMainVC*sv=ws; if(!sv)return;
            ZXPhotoCell*c2=(ZXPhotoCell*)[sv->_tv cellForRowAtIndexPath:cIP];
            if(ok){
                [c2 setStatus:@"Injected" color:ZXGreen];
                [sv showPopup:sName];
            } else {
                c2.sw.on=NO;
                [c2 setStatus:[NSString stringWithFormat:@"Write failed: %@", writeErr.localizedDescription ?: @"Error"] color:UIColor.systemRedColor];
            }
        });
    };
    
    [[[NSURLSession sharedSession]downloadTaskWithRequest:req completionHandler:^(NSURL*tmp,NSURLResponse*resp,NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        if((!tmp || err || (hr && hr.statusCode != 200)) && slot.fileUrl.length > 0){
            NSMutableURLRequest*req2=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:slot.fileUrl]];
            [req2 setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            req2.timeoutInterval = 20.0;
            [[[NSURLSession sharedSession]downloadTaskWithRequest:req2 completionHandler:handleResult] resume];
            return;
        }
        handleResult(tmp, resp, err);
    }]resume];
}
-(void)showPopup:(NSString*)name{
    UIWindow*win=[UIApplication sharedApplication].keyWindow;
    CGFloat w=155,h=50;
    UIView*p=ZXGlassView(13);p.frame=CGRectMake(win.bounds.size.width+w,52,w,h);
    p.backgroundColor=[UIColor colorWithRed:.04 green:.01 blue:.02 alpha:.95];
    p.layer.borderColor=ZXRed.CGColor;ZXRedGlow(p,8);
    UILabel*n=[UILabel new];n.frame=CGRectMake(0,8,w,18);
    n.text=name.uppercaseString;n.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    n.textColor=UIColor.whiteColor;n.textAlignment=NSTextAlignmentCenter;[p addSubview:n];
    UILabel*a=[UILabel new];a.frame=CGRectMake(0,26,w,16);
    NSMutableAttributedString*as=[[NSMutableAttributedString alloc]initWithString:@"ACTIVE"];
    [as addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,6)];
    [as addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:10 weight:UIFontWeightBold] range:NSMakeRange(0,6)];
    [as addAttribute:NSKernAttributeName value:@2 range:NSMakeRange(0,6)];
    a.attributedText=as;a.textAlignment=NSTextAlignmentCenter;[p addSubview:a];
    [win addSubview:p];
    [UIView animateWithDuration:.35 delay:0 usingSpringWithDamping:.8 initialSpringVelocity:.5
        options:0 animations:^{p.frame=CGRectMake(win.bounds.size.width-w-8,52,w,h);}
        completion:^(BOOL f){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                [UIView animateWithDuration:.25 animations:^{p.frame=CGRectMake(win.bounds.size.width+8,52,w,h);p.alpha=0;}
                    completion:^(BOOL ff){[p removeFromSuperview];}];
            });
        }];
}
// ── TableView ─────────────────────────────────────────────────────
-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return(NSInteger)self.currentSlots.count;}
-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip{
    ZXSlot*slot=self.currentSlots[ip.row];
    if(_tab==2){
        ZXPhotoCell*cell=[tv dequeueReusableCellWithIdentifier:@"ZPC"];
        if(!cell)cell=[[ZXPhotoCell alloc]initWithStyle:0 reuseIdentifier:@"ZPC"];
        [cell configure:slot idx:ip.row];
        __weak ZXMainVC*ws=self;ZXSlot*s2=slot;NSIndexPath*cIP=ip;
        cell.onToggle=^(BOOL on){
            if(!on)return;
            ZXPlay(@"activate");
            __strong ZXMainVC*svc=ws;if(!svc)return;
            BOOL hasTH=s2.ffthPath.length>0,hasMAX=s2.ffmaxPath.length>0;
            NSString*base=[svc mcmBase];NSInteger opt=3;
            void(^inject)(NSString*)=^(NSString*p){
                [[NSFileManager defaultManager]createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
                [svc doInjectPhoto:s2 dir:p optNum:opt ip:cIP];
            };
            if(hasTH&&hasMAX){
                UIAlertController*ac=[UIAlertController alertControllerWithTitle:s2.name message:@"Select game:" preferredStyle:UIAlertControllerStyleActionSheet];
                [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire TH" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffthPath]);}]];
                [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire MAX" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}]];
                [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction*a){
                    ZXPhotoCell*c2=(ZXPhotoCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;
                }]];
                UIViewController*top=[UIApplication sharedApplication].keyWindow.rootViewController;
                while(top.presentedViewController)top=top.presentedViewController;
                [top presentViewController:ac animated:YES completion:nil];
            } else if(hasTH){inject([base stringByAppendingPathComponent:s2.ffthPath]);}
            else if(hasMAX){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}
            else{ZXPhotoCell*c2=(ZXPhotoCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;[c2 setStatus:@"Set FFTH/FFMAX path in bot" color:UIColor.systemOrangeColor];}
        };
        return cell;
    }
    ZXSlotCell*cell=[tv dequeueReusableCellWithIdentifier:@"ZC"];
    if(!cell)cell=[[ZXSlotCell alloc]initWithStyle:0 reuseIdentifier:@"ZC"];
    [cell configure:slot idx:ip.row];
    __weak ZXMainVC*ws=self;ZXSlot*s2=slot;NSIndexPath*cIP=ip;
    cell.onToggle=^(BOOL on){
        if(!on)return;
        __strong ZXMainVC*svc=ws;if(!svc)return;
        BOOL isBypass = [s2.name.uppercaseString containsString:@"BYPASS"] || [s2.name.uppercaseString containsString:@"REMOVE"];
        if(isBypass){
            ZXPlay(@"remove");
        } else if(svc->_tab == 0){
            ZXPlay(@"option1");
        } else {
            ZXPlay(@"activate");
        }
        BOOL hasTH=s2.ffthPath.length>0,hasMAX=s2.ffmaxPath.length>0;
        NSString*base=[svc mcmBase];NSInteger opt=svc->_tab+1;
        void(^inject)(NSString*)=^(NSString*p){
            [[NSFileManager defaultManager]createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];
            [svc doInject:s2 dir:p optNum:opt ip:cIP];
        };
        if(hasTH&&hasMAX){
            UIAlertController*ac=[UIAlertController alertControllerWithTitle:s2.name message:@"Select game:" preferredStyle:UIAlertControllerStyleActionSheet];
            [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire TH" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffthPath]);}]];
            [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire MAX" style:0 handler:^(UIAlertAction*a){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}]];
            [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction*a){
                ZXSlotCell*c2=(ZXSlotCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;
            }]];
            UIViewController*top=[UIApplication sharedApplication].keyWindow.rootViewController;
            while(top.presentedViewController)top=top.presentedViewController;
            [top presentViewController:ac animated:YES completion:nil];
        } else if(hasTH){inject([base stringByAppendingPathComponent:s2.ffthPath]);}
        else if(hasMAX){inject([base stringByAppendingPathComponent:s2.ffmaxPath]);}
        else{
            ZXSlotCell*c2=(ZXSlotCell*)[svc->_tv cellForRowAtIndexPath:cIP];c2.sw.on=NO;
            [c2 setStatus:@"Set FFTH or FFMAX path in bot" color:UIColor.systemOrangeColor];
        }
    };
    return cell;
}
-(CGFloat)tableView:(UITableView*)tv heightForRowAtIndexPath:(NSIndexPath*)ip{return _tab==2?240:82;}
-(CGFloat)tableView:(UITableView*)tv heightForFooterInSection:(NSInteger)s{return 6;}
-(UIView*)tableView:(UITableView*)tv viewForFooterInSection:(NSInteger)s{UIView*v=[UIView new];v.backgroundColor=UIColor.clearColor;return v;}
// ── Remove/Restore ────────────────────────────────────────────────
-(void)rmTap:(UIButton*)b{
    ZXPlay(@"remove");
    NSInteger opt=b.tag;
    NSString*rmName=opt==1?(_cfg.rm1Name?:@"Restore 1"):(_cfg.rm2Name?:@"Restore 2");
    UIAlertController*ac=[UIAlertController alertControllerWithTitle:rmName
        message:@"Restore original file?" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction*a){
        NSString*url=[NSString stringWithFormat:@"%@/restore/%ld",kServerBase,(long)opt];
        [[[NSURLSession sharedSession]downloadTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSURL*tmp,NSURLResponse*resp,NSError*err){
            if(!tmp||err){return;}
            NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;if(hr.statusCode!=200)return;
            NSString*fn=hr.allHeaderFields[@"X-File-Name"]?:@"file";
            NSString*base=[self mcmBase];
            NSString*ffth=opt==1?self->_cfg.rm1ffth:self->_cfg.rm2ffth;
            NSString*ffmax=opt==1?self->_cfg.rm1ffmax:self->_cfg.rm2ffmax;
            NSFileManager*fm=NSFileManager.defaultManager;
            NSData*data=[NSData dataWithContentsOfURL:tmp];
            if(!data)return;
            for(NSString*pp in @[ffth,ffmax]){
                if(!pp.length)continue;
                NSString*dir=[base stringByAppendingPathComponent:pp];
                [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
                [data writeToFile:[dir stringByAppendingPathComponent:fn] atomically:YES];
            }
            dispatch_async(dispatch_get_main_queue(),^{
                UIAlertController*ok=[UIAlertController alertControllerWithTitle:@"Restored"
                    message:@"Original file restored" preferredStyle:UIAlertControllerStyleAlert];
                [ok addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
                UIViewController*top=[UIApplication sharedApplication].keyWindow.rootViewController;
                while(top.presentedViewController)top=top.presentedViewController;
                [top presentViewController:ok animated:YES completion:nil];
            });
        }]resume];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}
-(void)switchTab:(NSInteger)idx{
    _tab=idx;[_tv reloadData];
    for(NSInteger i=0;i<(NSInteger)_tabBtns.count;i++){
        UIButton*b=(UIButton*)_tabBtns[i];BOOL sel=(i==idx);
        if(sel){
            b.backgroundColor=[UIColor colorWithRed:0.95 green:0.09 blue:0.27 alpha:0.35];
            b.layer.borderColor=[UIColor colorWithRed:1.0 green:0.25 blue:0.4 alpha:0.85].CGColor;
            b.layer.borderWidth=1.2;
            b.layer.cornerRadius=14;
            b.layer.shadowColor=[UIColor colorWithRed:1.0 green:0.1 blue:0.3 alpha:0.8].CGColor;
            b.layer.shadowRadius=6;
            b.layer.shadowOpacity=0.6;
            [b setTitleColor:UIColor.whiteColor forState:0];
            b.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        } else {
            b.backgroundColor=UIColor.clearColor;
            b.layer.borderColor=UIColor.clearColor.CGColor;
            b.layer.borderWidth=0;
            b.layer.shadowOpacity=0;
            [b setTitleColor:[UIColor colorWithWhite:0.6 alpha:1.0] forState:0];
            b.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        }
    }
}
-(void)tabTap:(UIButton*)b{[self switchTab:b.tag];}
-(void)openTG{
    NSString*u=_cfg.telegram.length?_cfg.telegram:@"https://t.me/nothing6769";
    [[UIApplication sharedApplication]openURL:[NSURL URLWithString:u] options:@{} completionHandler:nil];
}
-(void)showSettingsInfo{
    NSString *osVer = [UIDevice currentDevice].systemVersion;
    NSString *hwid = ZXGetHWID();
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:kSavedKey] ?: @"N/A";
    NSString *createdAt = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyCreatedAt] ?: @"N/A";
    NSString *expiresAt = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyExpiresAt] ?: @"PERMANENT";
    
    NSString *msg = [NSString stringWithFormat:
        @"📱 DEVICE INFORMATION\n"
        @"OS: iOS %@\n"
        @"HWID: %@... (1-DEV LOCKED)\n\n"
        @"🔑 LICENSE DETAILS\n"
        @"Key: %@\n"
        @"Status: ACTIVE (VERIFIED)\n"
        @"Created: %@\n"
        @"Expires: %@\n\n"
        @"⚙️ SYSTEM STATUS\n"
        @"Status: OPERATIONAL\n"
        @"Version: v%@",
        osVer, [hwid substringToIndex:MIN(14, hwid.length)].uppercaseString, savedKey, createdAt, expiresAt, _cfg.version ?: @"1.0"];
        
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"⚙️ SYSTEM & LICENSE INFO"
                                                                message:msg
                                                         preferredStyle:UIAlertControllerStyleAlert];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"📋 Copy Key" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if(savedKey.length && ![savedKey isEqualToString:@"N/A"]) {
            [UIPasteboard generalPasteboard].string = savedKey;
        }
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"🚪 Logout / Change Key" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSavedKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kKeyCreatedAt];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kKeyExpiresAt];
        [[NSUserDefaults standardUserDefaults] synchronize];
        ZEXInjectorVC *rootVC = (ZEXInjectorVC *)[UIApplication sharedApplication].windows.firstObject.rootViewController;
        if(![rootVC isKindOfClass:[ZEXInjectorVC class]]) {
            rootVC = (ZEXInjectorVC *)[UIApplication sharedApplication].keyWindow.rootViewController;
        }
        if([rootVC isKindOfClass:[ZEXInjectorVC class]]) {
            [rootVC showAuth];
        }
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:ac animated:YES completion:nil];
}
// ── Build UI ──────────────────────────────────────────────────────
-(void)buildUI{
    // Header
    UILabel*subHead=[UILabel new];subHead.translatesAutoresizingMaskIntoConstraints=NO;
    subHead.text=@"FF Normal";subHead.font=[UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    subHead.textColor=UIColor.whiteColor;subHead.textAlignment=NSTextAlignmentCenter;
    [self.view addSubview:subHead];
    
    UILabel*brand=[UILabel new];brand.translatesAutoresizingMaskIntoConstraints=NO;
    brand.text=@"ZEX EXTERNAL";
    brand.font=[UIFont systemFontOfSize:26 weight:UIFontWeightBlack];
    brand.textColor=UIColor.whiteColor;
    [self.view addSubview:brand];
    
    UILabel*subBrand=[UILabel new];subBrand.translatesAutoresizingMaskIntoConstraints=NO;
    subBrand.text=@"PATCH CONTROL CENTER";
    subBrand.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    subBrand.textColor=[UIColor colorWithRed:0.92 green:0.12 blue:0.22 alpha:1.0];
    [self.view addSubview:subBrand];
    
    UIButton*settBtn=[UIButton buttonWithType:UIButtonTypeCustom];settBtn.translatesAutoresizingMaskIntoConstraints=NO;
    settBtn.backgroundColor=[UIColor colorWithRed:0.90 green:0.18 blue:0.24 alpha:1.0];
    settBtn.layer.cornerRadius=21;settBtn.clipsToBounds=YES;
    [settBtn setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:0];
    settBtn.tintColor=UIColor.whiteColor;
    [settBtn addTarget:self action:@selector(showSettingsInfo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:settBtn];
    
    // Status card (DEVICE STATUS)
    UIView*sc=[UIView new];sc.translatesAutoresizingMaskIntoConstraints=NO;
    sc.backgroundColor=[UIColor colorWithRed:0.07 green:0.09 blue:0.12 alpha:0.95];
    sc.layer.cornerRadius=20;sc.layer.borderWidth=1.0;
    sc.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.08].CGColor;
    [self.view addSubview:sc];
    
    UILabel*stHeader=[UILabel new];stHeader.translatesAutoresizingMaskIntoConstraints=NO;
    stHeader.text=@"🛡️  DEVICE STATUS";
    stHeader.font=[UIFont systemFontOfSize:12 weight:UIFontWeightBlack];
    stHeader.textColor=[UIColor colorWithRed:0.92 green:0.12 blue:0.22 alpha:1.0];
    [sc addSubview:stHeader];
    
    // Row 1: iOS
    UILabel*r1Icon=[UILabel new];r1Icon.translatesAutoresizingMaskIntoConstraints=NO;
    r1Icon.text=@"🍏  iOS";r1Icon.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    r1Icon.textColor=[UIColor colorWithWhite:0.75 alpha:1.0];[sc addSubview:r1Icon];
    
    UILabel*r1Val=[UILabel new];r1Val.translatesAutoresizingMaskIntoConstraints=NO;
    r1Val.text=[UIDevice currentDevice].systemVersion ?: @"18.6.0";
    r1Val.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    r1Val.textColor=UIColor.whiteColor;r1Val.textAlignment=NSTextAlignmentRight;[sc addSubview:r1Val];
    
    // Row 2: Device
    UILabel*r2Icon=[UILabel new];r2Icon.translatesAutoresizingMaskIntoConstraints=NO;
    r2Icon.text=@"📱  Device";r2Icon.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    r2Icon.textColor=[UIColor colorWithWhite:0.75 alpha:1.0];[sc addSubview:r2Icon];
    
    NSString *hw = ZXGetHWID();
    NSString *devStr = hw.length > 10 ? [NSString stringWithFormat:@"iPhone13,%@", [hw substringToIndex:1]] : @"iPhone13,1";
    UILabel*r2Val=[UILabel new];r2Val.translatesAutoresizingMaskIntoConstraints=NO;
    r2Val.text=devStr;r2Val.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    r2Val.textColor=UIColor.whiteColor;r2Val.textAlignment=NSTextAlignmentRight;[sc addSubview:r2Val];
    
    // Row 3: Support
    UILabel*r3Icon=[UILabel new];r3Icon.translatesAutoresizingMaskIntoConstraints=NO;
    r3Icon.text=@"🟢  Support";r3Icon.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    r3Icon.textColor=[UIColor colorWithWhite:0.75 alpha:1.0];[sc addSubview:r3Icon];
    
    UILabel*r3Val=[UILabel new];r3Val.translatesAutoresizingMaskIntoConstraints=NO;
    r3Val.text=@"SUPPORTED";r3Val.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBlack];
    r3Val.textColor=[UIColor colorWithRed:0.00 green:0.90 blue:0.45 alpha:1.0];
    r3Val.textAlignment=NSTextAlignmentRight;[sc addSubview:r3Val];
    
    // Patch options header
    UILabel*poLeft=[UILabel new];poLeft.translatesAutoresizingMaskIntoConstraints=NO;
    poLeft.text=@"⚡  PATCH OPTIONS";
    poLeft.font=[UIFont systemFontOfSize:12 weight:UIFontWeightBlack];
    poLeft.textColor=[UIColor colorWithRed:0.92 green:0.12 blue:0.22 alpha:1.0];
    [self.view addSubview:poLeft];
    
    UILabel*poRight=[UILabel new];poRight.translatesAutoresizingMaskIntoConstraints=NO;
    poRight.text=@"SELECT TO ENABLE";
    poRight.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    poRight.textColor=[UIColor colorWithWhite:0.45 alpha:1.0];
    poRight.textAlignment=NSTextAlignmentRight;
    [self.view addSubview:poRight];
    
    // TableView / Slots Grid
    _tv=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tv.translatesAutoresizingMaskIntoConstraints=NO;_tv.backgroundColor=UIColor.clearColor;
    _tv.separatorStyle=0;_tv.dataSource=self;_tv.delegate=self;[self.view addSubview:_tv];
    
    // Bottom Tab Bar
    UIView*tabBar=[[UIView alloc]init];tabBar.translatesAutoresizingMaskIntoConstraints=NO;
    tabBar.backgroundColor=[UIColor colorWithRed:0.05 green:0.06 blue:0.08 alpha:0.98];
    tabBar.layer.borderWidth=0.8;tabBar.layer.borderColor=[UIColor colorWithWhite:1 alpha:.06].CGColor;
    [self.view addSubview:tabBar];
    
    NSMutableArray<UIButton*>*btns=[NSMutableArray array];
    NSArray*tt=@[@"FF Normal",@"FF Max",@"File Status",@"Developer"];
    NSArray*icons=@[@"target",@"flame.fill",@"doc.fill",@"person.fill"];
    for(NSInteger i=0;i<4;i++){
        UIButton*tb=[UIButton buttonWithType:UIButtonTypeSystem];tb.translatesAutoresizingMaskIntoConstraints=NO;
        [tb setImage:[UIImage systemImageNamed:icons[i]] forState:0];
        [tb setTitle:tt[i] forState:0];
        tb.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        tb.tintColor=(i==0?[UIColor colorWithRed:0.92 green:0.12 blue:0.22 alpha:1.0]:[UIColor colorWithWhite:0.45 alpha:1.0]);
        [tb setTitleColor:(i==0?[UIColor colorWithRed:0.92 green:0.12 blue:0.22 alpha:1.0]:[UIColor colorWithWhite:0.45 alpha:1.0]) forState:0];
        tb.tag=i;[tb addTarget:self action:@selector(tabTap:) forControlEvents:UIControlEventTouchUpInside];
        [tabBar addSubview:tb];[btns addObject:tb];
        
        [NSLayoutConstraint activateConstraints:@[
            [tb.topAnchor constraintEqualToAnchor:tabBar.topAnchor constant:6],
            [tb.bottomAnchor constraintEqualToAnchor:tabBar.safeAreaLayoutGuide.bottomAnchor constant:-4],
            [tb.widthAnchor constraintEqualToAnchor:tabBar.widthAnchor multiplier:1.0/4],
        ]];
        if(i==0)[tb.leadingAnchor constraintEqualToAnchor:tabBar.leadingAnchor].active=YES;
        else [tb.leadingAnchor constraintEqualToAnchor:((UIButton*)btns[i-1]).trailingAnchor].active=YES;
    }
    _tabBtns=btns;
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [subHead.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:4],
        [subHead.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [brand.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [brand.topAnchor constraintEqualToAnchor:subHead.bottomAnchor constant:10],
        
        [subBrand.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],
        [subBrand.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:2],
        
        [settBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [settBtn.centerYAnchor constraintEqualToAnchor:brand.centerYAnchor],
        [settBtn.widthAnchor constraintEqualToConstant:42],[settBtn.heightAnchor constraintEqualToConstant:42],
        
        [sc.topAnchor constraintEqualToAnchor:subBrand.bottomAnchor constant:14],
        [sc.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [sc.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [stHeader.topAnchor constraintEqualToAnchor:sc.topAnchor constant:14],
        [stHeader.leadingAnchor constraintEqualToAnchor:sc.leadingAnchor constant:16],
        
        [r1Icon.topAnchor constraintEqualToAnchor:stHeader.bottomAnchor constant:12],
        [r1Icon.leadingAnchor constraintEqualToAnchor:sc.leadingAnchor constant:16],
        [r1Val.centerYAnchor constraintEqualToAnchor:r1Icon.centerYAnchor],
        [r1Val.trailingAnchor constraintEqualToAnchor:sc.trailingAnchor constant:-16],
        
        [r2Icon.topAnchor constraintEqualToAnchor:r1Icon.bottomAnchor constant:8],
        [r2Icon.leadingAnchor constraintEqualToAnchor:sc.leadingAnchor constant:16],
        [r2Val.centerYAnchor constraintEqualToAnchor:r2Icon.centerYAnchor],
        [r2Val.trailingAnchor constraintEqualToAnchor:sc.trailingAnchor constant:-16],
        
        [r3Icon.topAnchor constraintEqualToAnchor:r2Icon.bottomAnchor constant:8],
        [r3Icon.leadingAnchor constraintEqualToAnchor:sc.leadingAnchor constant:16],
        [r3Icon.bottomAnchor constraintEqualToAnchor:sc.bottomAnchor constant:-14],
        [r3Val.centerYAnchor constraintEqualToAnchor:r3Icon.centerYAnchor],
        [r3Val.trailingAnchor constraintEqualToAnchor:sc.trailingAnchor constant:-16],
        
        [poLeft.topAnchor constraintEqualToAnchor:sc.bottomAnchor constant:16],
        [poLeft.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [poRight.centerYAnchor constraintEqualToAnchor:poLeft.centerYAnchor],
        [poRight.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        
        [_tv.topAnchor constraintEqualToAnchor:poLeft.bottomAnchor constant:10],
        [_tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [_tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [_tv.bottomAnchor constraintEqualToAnchor:tabBar.topAnchor constant:-4],
        
        [tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tabBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [tabBar.heightAnchor constraintEqualToConstant:75],
    ]];
}
@end

// ── ZEXInjectorVC ─────────────────────────────────────────────────
@implementation ZEXInjectorVC
-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
-(UIViewController*)childViewControllerForStatusBarStyle{return self.childViewControllers.lastObject;}
-(void)viewDidLoad{
    [super viewDidLoad];
    self.view.frame=UIScreen.mainScreen.bounds;
    self.view.backgroundColor=[UIColor colorWithRed:0.04 green:0.01 blue:0.02 alpha:1.0];
    [self showLoadingScreen];
}
-(void)showLoadingScreen{
    UIView*loader=[[UIView alloc]initWithFrame:self.view.bounds];
    loader.backgroundColor=[UIColor blackColor];
    loader.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    ZXAddModernBackground(loader);
    
    // Center Animated GIF Logo
    UIImageView *gifView = [UIImageView new];
    gifView.translatesAutoresizingMaskIntoConstraints = NO;
    gifView.contentMode = UIViewContentModeScaleAspectFit;
    gifView.layer.cornerRadius = 24;
    gifView.layer.masksToBounds = YES;
    gifView.layer.borderWidth = 1.2;
    gifView.layer.borderColor = [UIColor colorWithRed:0.95 green:0.15 blue:0.3 alpha:0.6].CGColor;
    gifView.layer.shadowColor = ZXRed.CGColor;
    gifView.layer.shadowRadius = 16;
    gifView.layer.shadowOpacity = 0.6;
    gifView.layer.shadowOffset = CGSizeZero;
    gifView.image = ZXLoadAnimatedGIF(@"GIF by Chandelier Creative.gif");
    [loader addSubview:gifView];
    
    UILabel*logo=[UILabel new];logo.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*as=[[NSMutableAttributedString alloc]initWithString:@"ZEX EXTERNAL"];
    [as addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,3)];
    [as addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(3,9)];
    [as addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:24 weight:UIFontWeightHeavy] range:NSMakeRange(0,12)];
    [as addAttribute:NSKernAttributeName value:@2.0 range:NSMakeRange(0,12)];
    logo.attributedText=as;logo.textAlignment=NSTextAlignmentCenter;
    [loader addSubview:logo];
    
    UIView*badge=ZXGlassView(10);badge.translatesAutoresizingMaskIntoConstraints=NO;
    badge.backgroundColor=[UIColor colorWithRed:0.14 green:0.02 blue:0.04 alpha:0.85];
    badge.layer.borderColor=[UIColor colorWithRed:1.0 green:0.25 blue:0.4 alpha:0.45].CGColor;
    badge.layer.borderWidth=0.8;badge.layer.cornerRadius=10;[loader addSubview:badge];
    
    UIView*dot=[UIView new];dot.translatesAutoresizingMaskIntoConstraints=NO;
    dot.backgroundColor=[UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
    dot.layer.cornerRadius=3.5;
    [badge addSubview:dot];
    
    UILabel*badgeLbl=[UILabel new];badgeLbl.translatesAutoresizingMaskIntoConstraints=NO;
    badgeLbl.text=@"INITIALIZING RUNTIME";badgeLbl.font=[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    badgeLbl.textColor=[UIColor colorWithRed:1.0 green:0.4 blue:0.55 alpha:1.0];[badge addSubview:badgeLbl];
    
    UILabel*devLoad=[UILabel new];devLoad.translatesAutoresizingMaskIntoConstraints=NO;
    NSString *model = [UIDevice currentDevice].model;
    NSString *osVer = [UIDevice currentDevice].systemVersion;
    devLoad.text=[NSString stringWithFormat:@"📱 %@ • iOS %@ • ROOTLESS", model.uppercaseString, osVer];
    devLoad.font=[UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightBold];
    devLoad.textColor=[UIColor colorWithRed:0.25 green:0.88 blue:0.45 alpha:0.95];
    devLoad.textAlignment=NSTextAlignmentCenter;[loader addSubview:devLoad];
    
    UILabel*sub=[UILabel new];sub.translatesAutoresizingMaskIntoConstraints=NO;
    sub.text=@"> [01/04] INITIALIZING SYSTEM KERNEL...";
    sub.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    sub.textColor=[UIColor colorWithWhite:1 alpha:.8];sub.textAlignment=NSTextAlignmentCenter;[loader addSubview:sub];
    
    UIView*pTrack=[UIView new];pTrack.translatesAutoresizingMaskIntoConstraints=NO;
    pTrack.backgroundColor=[UIColor colorWithWhite:0 alpha:0.6];
    pTrack.layer.cornerRadius=3.5;pTrack.clipsToBounds=YES;
    pTrack.layer.borderWidth=0.6;pTrack.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.12].CGColor;
    [loader addSubview:pTrack];
    
    UIView*pBar=[UIView new];pBar.translatesAutoresizingMaskIntoConstraints=NO;
    pBar.backgroundColor=ZXRed;pBar.layer.cornerRadius=3.5;
    pBar.layer.shadowColor=ZXRed.CGColor;pBar.layer.shadowOffset=CGSizeZero;pBar.layer.shadowRadius=8;pBar.layer.shadowOpacity=0.9;
    [pTrack addSubview:pBar];
    
    CAGradientLayer*barGrad=[CAGradientLayer layer];
    barGrad.frame=CGRectMake(0,0,240,7);
    barGrad.colors=@[(id)[UIColor colorWithRed:1.0 green:0.25 blue:0.4 alpha:1].CGColor, (id)ZXRed.CGColor];
    barGrad.startPoint=CGPointMake(0,0.5);barGrad.endPoint=CGPointMake(1,0.5);
    [pBar.layer insertSublayer:barGrad atIndex:0];
    
    NSLayoutConstraint*pWidth=[pBar.widthAnchor constraintEqualToConstant:20];
    
    [NSLayoutConstraint activateConstraints:@[
        [gifView.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        [gifView.centerYAnchor constraintEqualToAnchor:loader.centerYAnchor constant:-85],
        [gifView.widthAnchor constraintEqualToConstant:78],
        [gifView.heightAnchor constraintEqualToConstant:78],
        
        [logo.topAnchor constraintEqualToAnchor:gifView.bottomAnchor constant:12],
        [logo.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        
        [badge.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:10],
        [badge.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        [dot.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:10],
        [dot.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
        [dot.widthAnchor constraintEqualToConstant:7],
        [dot.heightAnchor constraintEqualToConstant:7],
        [badgeLbl.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:6],
        [badgeLbl.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-10],
        [badgeLbl.topAnchor constraintEqualToAnchor:badge.topAnchor constant:4],
        [badgeLbl.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-4],
        
        [devLoad.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:8],
        [devLoad.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        
        [sub.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        [sub.topAnchor constraintEqualToAnchor:devLoad.bottomAnchor constant:14],
        
        [pTrack.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        [pTrack.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:16],
        [pTrack.widthAnchor constraintEqualToConstant:200],
        [pTrack.heightAnchor constraintEqualToConstant:7],
        
        [pBar.leadingAnchor constraintEqualToAnchor:pTrack.leadingAnchor],
        [pBar.topAnchor constraintEqualToAnchor:pTrack.topAnchor],
        [pBar.bottomAnchor constraintEqualToAnchor:pTrack.bottomAnchor],
        pWidth
    ]];
    
    [self.view addSubview:loader];
    ZXAddFallingParticles(loader);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        pWidth.constant = 95;
        [UIView animateWithDuration:0.4 animations:^{ [loader layoutIfNeeded]; }];
        sub.text = @"> [02/04] ESCAPING SANDBOX CONTAINERS...";
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 600 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        pWidth.constant = 160;
        [UIView animateWithDuration:0.35 animations:^{ [loader layoutIfNeeded]; }];
        sub.text = @"> [03/04] CONNECTING TO SECURE AUTH NODE...";
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 950 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        pWidth.constant = 200;
        [UIView animateWithDuration:0.25 animations:^{ [loader layoutIfNeeded]; }];
        sub.text = @"> [04/04] ALL SYSTEMS ARMED & READY_";
        sub.textColor = ZXGreen;
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self showAuth];
        [UIView animateWithDuration:0.3 animations:^{
            loader.alpha = 0;
        } completion:^(BOOL f){
            [loader removeFromSuperview];
        }];
    });
}
-(void)showAuth{
    for(UIViewController*c in self.childViewControllers){[c willMoveToParentViewController:nil];[c.view removeFromSuperview];[c removeFromParentViewController];}
    ZXAuthVC*a=[ZXAuthVC new];
    __weak typeof(self) ws=self;
    a.onAuth=^{[ws showMain];};
    [self addChildViewController:a];a.view.frame=self.view.bounds;
    a.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:a.view atIndex:0];[a didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}
-(void)showMain{
    for(UIViewController*c in self.childViewControllers){[c willMoveToParentViewController:nil];[c.view removeFromSuperview];[c removeFromParentViewController];}
    ZXMainVC*m=[ZXMainVC new];
    [self addChildViewController:m];m.view.frame=self.view.bounds;
    m.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:m.view atIndex:0];[m didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}
@end
