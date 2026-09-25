#import "ZEXInjectorVC.h"
#import "ZEXFileService.h"
#import "MCMBridge.h"
#import "MCMFilzaIntegration.h"
#import "apfs_own.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const kServerBase    = @"http://213.199.53.54:9008";
static NSString *const kCfgURL        = @"http://213.199.53.54:9008/config";
static NSString *const kSavedKey      = @"zex_auth_key_v1";
static NSString *const kSaveKeyToggle = @"zex_save_key_toggle";

// ── Real Application Container Resolution (Bypasses Sandbox fallback) ──
static NSString *ZXResolveAppContainerPath(NSString *bundleId) {
    if (!bundleId.length) return nil;
    
    // 1. Try MobileContainerManager API (MCMLease)
    NSString *err = nil;
    MCMLease *lease = [MCMLease leaseForClass:2 identifier:bundleId group:NO part:0 flags:0x8100000000ULL error:&err];
    if (lease && lease.rootPath.length) {
        return lease.rootPath;
    }
    
    // 2. Scan /private/var/mobile/Containers/Data/Application metadata plists directly
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *appContainersRoot = @"/private/var/mobile/Containers/Data/Application";
    NSArray *uuids = [fm contentsOfDirectoryAtPath:appContainersRoot error:nil];
    for (NSString *uuid in uuids ?: @[]) {
        NSString *cPath = [appContainersRoot stringByAppendingPathComponent:uuid];
        NSString *metaPath = [cPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        if (dict && [dict[@"MCMMetadataIdentifier"] isEqualToString:bundleId]) {
            return cPath;
        }
    }
    
    // 3. Resolve Filza Virtual Root Symlink
    NSString *vRoot = ZEXFileService.shared.virtualRoot;
    if (vRoot.length) {
        NSString *link = [[vRoot stringByAppendingPathComponent:@"[MHA-C2] App Data"] stringByAppendingPathComponent:bundleId];
        NSString *dest = [fm destinationOfSymbolicLinkAtPath:link error:nil];
        if (dest.length) return dest;
        if ([fm fileExistsAtPath:link]) return link;
    }
    
    return nil;
}

static NSString* ZXGetHWID(void) {
    NSString *k = @"com.zex.injector.hwid";
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:k];
    if (saved.length) return saved;
    NSString *vendor = [UIDevice currentDevice].identifierForVendor.UUIDString;
    if (!vendor.length) vendor = [[NSUUID UUID] UUIDString];
    NSString *hwid = [vendor stringByReplacingOccurrencesOfString:@"-" withString:@""].lowercaseString;
    [[NSUserDefaults standardUserDefaults] setObject:hwid forKey:k];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return hwid;
}

#define ZXBg      [UIColor colorWithRed:.04 green:.05 blue:.08 alpha:1]
#define ZXRed     [UIColor colorWithRed:.92 green:.12 blue:.22 alpha:1]
#define ZXGray    [UIColor colorWithWhite:.5 alpha:1]
#define ZXGreen   [UIColor colorWithRed:.13 green:.77 blue:.36 alpha:1]

static void ZXPlaySound(NSString *name) {
    AudioServicesPlaySystemSound(1057);
}

@interface ZXSlot : NSObject
@property NSInteger slotId;
@property NSString *name,*desc,*fileUrl,*fileName,*imageUrl,*type;
@property NSString *ffthPath,*ffmaxPath,*subPath,*directPath;
@property BOOL isActivated;
@end
@implementation ZXSlot @end

@interface ZXConfig : NSObject
@property NSString *version,*telegram,*appName;
@property NSString *opt1Name,*opt2Name,*opt3Name,*opt4Name;
@property NSArray<ZXSlot*>*opt1,*opt2,*opt3,*opt4;
+(void)fetch:(void(^)(ZXConfig*,NSError*))cb;
@end

@implementation ZXConfig
+(ZXSlot*)slotFrom:(NSDictionary*)d{
    ZXSlot*s=[ZXSlot new];
    s.slotId=[d[@"id"]integerValue];
    s.name=d[@"name"]?:@"Slot";
    s.desc=d[@"description"]?:@"";
    s.fileUrl=d[@"fileUrl"]?:@"";
    s.fileName=d[@"fileName"]?:@"file";
    s.imageUrl=d[@"imageUrl"]?:@"";
    s.type=d[@"type"]?:@"A";
    s.ffthPath=d[@"ffthPath"]?:@"";
    s.ffmaxPath=d[@"ffmaxPath"]?:@"";
    s.subPath=d[@"subPath"]?:@"";
    s.directPath=d[@"directPath"]?:@"";
    return s;
}

+(ZXConfig*)defaultConfig {
    ZXConfig*c=[ZXConfig new];
    c.version=@"2.7.1";
    c.telegram=@"https://t.me/zexinjector";
    c.appName=@"ZEX FREE";
    c.opt1Name=@"FF Normal";c.opt2Name=@"FF Max";c.opt3Name=@"File Status";c.opt4Name=@"Developer";
    
    NSMutableArray*o1=[NSMutableArray array];
    NSArray*n1=@[@"Aim Drag",@"Aim Neck",@"Antenna",@"144 FPS"];
    for(NSInteger i=0;i<4;i++){
        ZXSlot*s=[ZXSlot new];s.slotId=i+1;s.name=n1[i];s.desc=@"FREE FIRE • NORMAL";
        s.fileName=[NSString stringWithFormat:@"slot%ld.bin",(long)(i+1)];
        s.ffthPath=@"com.dts.freefireth/Documents/contentcache/Compulsory/ios/gameassetbundles/";
        [o1 addObject:s];
    }
    
    NSMutableArray*o2=[NSMutableArray array];
    NSArray*n2=@[@"Aim Lock",@"Aim Assist",@"Wallhack",@"High FPS"];
    for(NSInteger i=0;i<4;i++){
        ZXSlot*s=[ZXSlot new];s.slotId=i+5;s.name=n2[i];s.desc=@"FREE FIRE • MAX";
        s.fileName=[NSString stringWithFormat:@"slot%ld.bin",(long)(i+5)];
        s.ffmaxPath=@"com.dts.freefiremax/Documents/contentcache/Compulsory/ios/gameassetbundles/";
        [o2 addObject:s];
    }
    
    NSMutableArray*o3=[NSMutableArray array];
    ZXSlot*s3=[ZXSlot new];s3.slotId=9;s3.name=@"Mod Skin V1";s3.desc=@"CUSTOM SKINS";[o3 addObject:s3];
    
    NSMutableArray*o4=[NSMutableArray array];
    ZXSlot*s4_1=[ZXSlot new];s4_1.slotId=10;s4_1.name=@"BYPASS FFTH";s4_1.desc=@"APPLY AFTER LEAVING GAME";
    s4_1.ffthPath=@"com.dts.freefireth/Documents/contentcache/Compulsory/ios/gameassetbundles/";
    [o4 addObject:s4_1];
    
    ZXSlot*s4_2=[ZXSlot new];s4_2.slotId=11;s4_2.name=@"BYPASS FF MAX";s4_2.desc=@"APPLY AFTER LEAVING GAME";
    s4_2.ffmaxPath=@"com.dts.freefiremax/Documents/contentcache/Compulsory/ios/gameassetbundles/";
    [o4 addObject:s4_2];
    
    c.opt1=o1;c.opt2=o2;c.opt3=o3;c.opt4=o4;
    return c;
}

+(void)fetch:(void(^)(ZXConfig*,NSError*))cb{
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:kCfgURL]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    req.timeoutInterval = 6.0;
    [[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData*d,NSURLResponse*r,NSError*e){
        if(!d||e){
            dispatch_async(dispatch_get_main_queue(),^{cb([ZXConfig defaultConfig],e);});
            return;
        }
        NSDictionary*j=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if(!j){
            dispatch_async(dispatch_get_main_queue(),^{cb([ZXConfig defaultConfig],nil);});
            return;
        }
        ZXConfig*c=[ZXConfig new];
        c.version=j[@"version"]?:@"2.7.1";
        c.telegram=j[@"telegram"]?:@"https://t.me/zexinjector";
        c.appName=j[@"appName"]?:@"ZEX FREE";
        c.opt1Name=j[@"option1Name"]?:@"FF Normal";
        c.opt2Name=j[@"option2Name"]?:@"FF Max";
        c.opt3Name=j[@"option3Name"]?:@"File Status";
        c.opt4Name=j[@"option4Name"]?:@"Developer";
        
        NSMutableArray*o1=[NSMutableArray array],*o2=[NSMutableArray array],*o3=[NSMutableArray array],*o4=[NSMutableArray array];
        for(NSDictionary*dd in j[@"option1Slots"]?:@[])[o1 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option2Slots"]?:@[])[o2 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option3Slots"]?:@[])[o3 addObject:[self slotFrom:dd]];
        for(NSDictionary*dd in j[@"option4Slots"]?:@[])[o4 addObject:[self slotFrom:dd]];
        
        ZXConfig*def = [ZXConfig defaultConfig];
        c.opt1 = o1.count ? o1 : def.opt1;
        c.opt2 = o2.count ? o2 : def.opt2;
        c.opt3 = o3.count ? o3 : def.opt3;
        c.opt4 = o4.count ? o4 : def.opt4;
        
        dispatch_async(dispatch_get_main_queue(),^{cb(c,nil);});
    }]resume];
}
@end

// ── Card Item for 2-Column Slot Grid ─────────────────────────────────
@interface ZXSlotCardView : UIView
@property (nonatomic, strong) ZXSlot *slot;
@property (nonatomic, copy) void(^onTap)(ZXSlotCardView *card);
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong) UILabel *statusLbl;
- (void)configureWithSlot:(ZXSlot *)slot subTitle:(NSString *)subTitle;
- (void)setStatusText:(NSString *)text color:(UIColor *)color;
@end

@implementation ZXSlotCardView {
    UILabel *_boltIcon;
    UILabel *_statusBadge;
    UILabel *_titleLabel;
    UILabel *_subLabel;
    UILabel *_dotIndicator;
    UITapGestureRecognizer *_tapGesture;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:0.95];
        self.layer.cornerRadius = 16;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
        self.clipsToBounds = YES;
        
        _boltIcon = [UILabel new];
        _boltIcon.text = @"⚡";
        _boltIcon.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBlack];
        _boltIcon.textColor = ZXRed;
        [self addSubview:_boltIcon];
        
        _statusBadge = [UILabel new];
        _statusBadge.text = @"OFF";
        _statusBadge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBlack];
        _statusBadge.textColor = ZXGray;
        _statusBadge.textAlignment = NSTextAlignmentRight;
        [self addSubview:_statusBadge];
        
        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
        _titleLabel.textColor = UIColor.whiteColor;
        [self addSubview:_titleLabel];
        
        _subLabel = [UILabel new];
        _subLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        _subLabel.textColor = [UIColor colorWithRed:0.92 green:0.12 blue:0.22 alpha:0.8];
        [self addSubview:_subLabel];
        
        _dotIndicator = [UILabel new];
        _dotIndicator.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold];
        _dotIndicator.text = @"● ACTIVATE PATCH";
        _dotIndicator.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
        [self addSubview:_dotIndicator];
        
        self.statusLbl = [UILabel new];
        self.statusLbl.font = [UIFont systemFontOfSize:8.5 weight:UIFontWeightMedium];
        self.statusLbl.textColor = ZXGray;
        self.statusLbl.numberOfLines = 2;
        [self addSubview:self.statusLbl];
        
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        [self addGestureRecognizer:_tapGesture];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    
    _boltIcon.frame = CGRectMake(12, 10, 24, 20);
    _statusBadge.frame = CGRectMake(w - 60, 10, 48, 20);
    _titleLabel.frame = CGRectMake(12, 36, w - 24, 20);
    _subLabel.frame = CGRectMake(12, 58, w - 24, 15);
    _dotIndicator.frame = CGRectMake(12, 80, w - 24, 15);
    self.statusLbl.frame = CGRectMake(12, 98, w - 24, 30);
}

- (void)configureWithSlot:(ZXSlot *)slot subTitle:(NSString *)subTitle {
    self.slot = slot;
    _titleLabel.text = slot.name;
    _subLabel.text = (slot.desc.length > 0) ? slot.desc : (subTitle ?: @"FREE FIRE • NORMAL");
    self.isActive = slot.isActivated;
    self.statusLbl.text = @"";
    [self updateUI];
}

- (void)setIsActive:(BOOL)isActive {
    _isActive = isActive;
    self.slot.isActivated = isActive;
    [self updateUI];
}

- (void)updateUI {
    if (_isActive) {
        self.layer.borderColor = ZXGreen.CGColor;
        self.layer.borderWidth = 1.6;
        
        _boltIcon.textColor = ZXGreen;
        _statusBadge.text = @"ON";
        _statusBadge.textColor = ZXGreen;
        _subLabel.textColor = ZXGreen;
        _dotIndicator.text = @"● PATCH ACTIVE";
        _dotIndicator.textColor = ZXGreen;
    } else {
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
        self.layer.borderWidth = 1.0;
        
        _boltIcon.textColor = ZXRed;
        _statusBadge.text = @"OFF";
        _statusBadge.textColor = ZXGray;
        _subLabel.textColor = [UIColor colorWithRed:0.92 green:0.12 blue:0.22 alpha:0.8];
        _dotIndicator.text = @"● ACTIVATE PATCH";
        _dotIndicator.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
    }
}

- (void)setStatusText:(NSString *)text color:(UIColor *)color {
    self.statusLbl.text = text;
    self.statusLbl.textColor = color ?: ZXGray;
}

- (void)handleTap {
    self.isActive = !self.isActive;
    if (self.onTap) {
        self.onTap(self);
    }
}
@end

// ── 2-Column TableView Row Cell ───────────────────────────────────────
@interface ZXGridRowCell : UITableViewCell
@property (nonatomic, strong) ZXSlotCardView *leftCard;
@property (nonatomic, strong) ZXSlotCardView *rightCard;
@end

@implementation ZXGridRowCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.leftCard = [ZXSlotCardView new];
        [self.contentView addSubview:self.leftCard];
        
        self.rightCard = [ZXSlotCardView new];
        [self.contentView addSubview:self.rightCard];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat cardW = (w - 12) / 2.0;
    CGFloat cardH = h - 8;
    
    self.leftCard.frame = CGRectMake(0, 4, cardW, cardH);
    self.rightCard.frame = CGRectMake(cardW + 12, 4, cardW, cardH);
}
@end

// ── ZXAuthVC (Login Screen) ───────────────────────────────────────────
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
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];

    UILabel*logo=[UILabel new];logo.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*as=[[NSMutableAttributedString alloc]initWithString:@"ZEX FREE"];
    [as addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,3)];
    [as addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(3,5)];
    [as addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:32 weight:UIFontWeightBlack] range:NSMakeRange(0,8)];
    [as addAttribute:NSKernAttributeName value:@2.5 range:NSMakeRange(0,8)];
    logo.attributedText=as;logo.textAlignment=NSTextAlignmentCenter;
    [self.view addSubview:logo];
    
    UILabel*subTitle=[UILabel new];subTitle.translatesAutoresizingMaskIntoConstraints=NO;
    subTitle.text=@"PATCH CONTROL CENTER";
    subTitle.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    subTitle.textColor=ZXRed;subTitle.textAlignment=NSTextAlignmentCenter;
    [self.view addSubview:subTitle];
    
    UILabel*devInfo=[UILabel new];devInfo.translatesAutoresizingMaskIntoConstraints=NO;
    NSString *model = [UIDevice currentDevice].model;
    NSString *osVer = [UIDevice currentDevice].systemVersion;
    devInfo.text=[NSString stringWithFormat:@"📱 %@ • iOS %@ • SUPPORTED", model.uppercaseString, osVer];
    devInfo.font=[UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightBold];
    devInfo.textColor=ZXGreen;
    devInfo.textAlignment=NSTextAlignmentCenter;
    [self.view addSubview:devInfo];
    
    _card = [UIView new];_card.translatesAutoresizingMaskIntoConstraints=NO;
    _card.backgroundColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.13 alpha:0.95];
    _card.layer.cornerRadius = 18;
    _card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    _card.layer.borderWidth = 1.0;
    [self.view addSubview:_card];
    
    UILabel*lbl=[UILabel new];lbl.translatesAutoresizingMaskIntoConstraints=NO;
    lbl.text=@"ENTER LICENSE KEY";lbl.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
    lbl.textColor=[UIColor colorWithRed:1.0 green:0.35 blue:0.5 alpha:1.0];[_card addSubview:lbl];
    
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
    _f.attributedPlaceholder=[[NSAttributedString alloc]initWithString:@"ZEX-FREE-9008"
        attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:.38 alpha:1],
                     NSFontAttributeName:[UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightMedium]}];
    
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:kSavedKey];
    if(savedKey.length) {
        _f.text = savedKey;
    } else {
        _f.text = @"ZEX-FREE-9008";
    }
    [inBox addSubview:_f];
    
    UIButton*pasteBtn=[UIButton buttonWithType:UIButtonTypeSystem];pasteBtn.translatesAutoresizingMaskIntoConstraints=NO;
    [pasteBtn setTitle:@"PASTE" forState:0];
    [pasteBtn setTitleColor:ZXRed forState:0];
    pasteBtn.titleLabel.font=[UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightBold];
    pasteBtn.backgroundColor=[UIColor colorWithRed:1.0 green:0.15 blue:0.3 alpha:0.15];
    pasteBtn.layer.cornerRadius=8;
    [pasteBtn addTarget:self action:@selector(pasteKey) forControlEvents:UIControlEventTouchUpInside];
    [inBox addSubview:pasteBtn];
    
    _btn=[UIButton buttonWithType:UIButtonTypeSystem];_btn.translatesAutoresizingMaskIntoConstraints=NO;
    [_btn setTitle:@"⚡ LOGIN TO ZEX FREE" forState:UIControlStateNormal];
    [_btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBlack];
    _btn.backgroundColor=ZXRed;_btn.layer.cornerRadius=16;
    [_btn addTarget:self action:@selector(activate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btn];
    
    _msg=[UILabel new];_msg.translatesAutoresizingMaskIntoConstraints=NO;
    _msg.textAlignment=NSTextAlignmentCenter;_msg.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightBold];
    _msg.numberOfLines=2;[self.view addSubview:_msg];
    
    _sp=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _sp.translatesAutoresizingMaskIntoConstraints=NO;_sp.color=ZXRed;_sp.hidesWhenStopped=YES;[self.view addSubview:_sp];
    
    [NSLayoutConstraint activateConstraints:@[
        [logo.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:50],
        [logo.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [subTitle.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:4],
        [subTitle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [devInfo.topAnchor constraintEqualToAnchor:subTitle.bottomAnchor constant:12],
        [devInfo.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [_card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:22],
        [_card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-22],
        [_card.topAnchor constraintEqualToAnchor:devInfo.bottomAnchor constant:24],
        
        [lbl.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:16],
        [lbl.topAnchor constraintEqualToAnchor:_card.topAnchor constant:16],
        
        [inBox.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14],
        [inBox.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-14],
        [inBox.topAnchor constraintEqualToAnchor:lbl.bottomAnchor constant:12],
        [inBox.heightAnchor constraintEqualToConstant:46],
        [inBox.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-16],
        
        [_f.leadingAnchor constraintEqualToAnchor:inBox.leadingAnchor constant:12],
        [_f.trailingAnchor constraintEqualToAnchor:pasteBtn.leadingAnchor constant:-6],
        [_f.topAnchor constraintEqualToAnchor:inBox.topAnchor],
        [_f.bottomAnchor constraintEqualToAnchor:inBox.bottomAnchor],
        
        [pasteBtn.trailingAnchor constraintEqualToAnchor:inBox.trailingAnchor constant:-6],
        [pasteBtn.centerYAnchor constraintEqualToAnchor:inBox.centerYAnchor],
        [pasteBtn.widthAnchor constraintEqualToConstant:54],
        [pasteBtn.heightAnchor constraintEqualToConstant:32],
        
        [_btn.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [_btn.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        [_btn.topAnchor constraintEqualToAnchor:_card.bottomAnchor constant:18],
        [_btn.heightAnchor constraintEqualToConstant:52],
        
        [_msg.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_msg.topAnchor constraintEqualToAnchor:_btn.bottomAnchor constant:14],
        [_msg.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [_msg.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        
        [_sp.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_sp.topAnchor constraintEqualToAnchor:_msg.bottomAnchor constant:6],
    ]];
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
        key = @"ZEX-FREE-9008";
    }
    
    [[NSUserDefaults standardUserDefaults]setObject:key forKey:kSavedKey];
    [[NSUserDefaults standardUserDefaults]synchronize];
    
    _msg.text=@"> Access Granted: ZEX FREE Authorized!";
    _msg.textColor=ZXGreen;
    ZXPlaySound(@"activate");
    
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        __strong typeof(ws) sv = ws;
        if (sv && sv.onAuth) {
            sv.onAuth();
        }
    });
}
@end

// ── ZXMainVC (Matches exact screenshot layout with Real Path Display) ───────
@interface ZXMainVC : UIViewController<UITableViewDataSource,UITableViewDelegate>
@end

@implementation ZXMainVC{
    ZXConfig*_cfg;NSInteger _tab;
    UILabel*_headerTabTitle;
    UITableView*_tv;
    NSArray<UIButton*>*_tabBtns;
}

-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}

-(NSArray<ZXSlot*>*)currentSlots{
    if(!_cfg) return [ZXConfig defaultConfig].opt1;
    return _tab==0?_cfg.opt1:_tab==1?_cfg.opt2:_tab==2?_cfg.opt3:_cfg.opt4?:@[];
}

-(NSString*)mcmBase{
    NSString*r=ZEXFileService.shared.virtualRoot;
    if(!r.length)r=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    return [r stringByAppendingPathComponent:@"[MHA-C2] App Data"];
}

-(void)viewDidLoad{
    [super viewDidLoad];_tab=0;
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    [self buildUI];
    [self loadConfig];
}

-(void)loadConfig{
    self->_cfg = [ZXConfig defaultConfig];
    [self->_tv reloadData];
    [ZXConfig fetch:^(ZXConfig*c,NSError*e){
        if(c){
            self->_cfg=c;
            [self->_tv reloadData];
        }
    }];
}

-(void)buildUI{
    UIView*topContainer=[UIView new];topContainer.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:topContainer];
    
    _headerTabTitle=[UILabel new];_headerTabTitle.translatesAutoresizingMaskIntoConstraints=NO;
    _headerTabTitle.text=@"FF Normal";
    _headerTabTitle.font=[UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    _headerTabTitle.textColor=[UIColor colorWithWhite:0.85 alpha:1.0];
    _headerTabTitle.textAlignment=NSTextAlignmentCenter;
    [topContainer addSubview:_headerTabTitle];
    
    UILabel*brand=[UILabel new];brand.translatesAutoresizingMaskIntoConstraints=NO;
    brand.text=@"ZEX FREE";
    brand.font=[UIFont systemFontOfSize:26 weight:UIFontWeightBlack];
    brand.textColor=UIColor.whiteColor;
    [topContainer addSubview:brand];
    
    UILabel*subBrand=[UILabel new];subBrand.translatesAutoresizingMaskIntoConstraints=NO;
    subBrand.text=@"PATCH CONTROL CENTER";
    subBrand.font=[UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    subBrand.textColor=ZXRed;
    [topContainer addSubview:subBrand];
    
    UIButton*settBtn=[UIButton buttonWithType:UIButtonTypeCustom];settBtn.translatesAutoresizingMaskIntoConstraints=NO;
    settBtn.backgroundColor=[UIColor colorWithRed:0.90 green:0.18 blue:0.24 alpha:1.0];
    settBtn.layer.cornerRadius=21;settBtn.clipsToBounds=YES;
    [settBtn setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:0];
    settBtn.tintColor=UIColor.whiteColor;
    [settBtn addTarget:self action:@selector(showSettingsInfo) forControlEvents:UIControlEventTouchUpInside];
    [topContainer addSubview:settBtn];
    
    // Status card (DEVICE STATUS)
    UIView*sc=[UIView new];sc.translatesAutoresizingMaskIntoConstraints=NO;
    sc.backgroundColor=[UIColor colorWithRed:0.06 green:0.08 blue:0.11 alpha:0.95];
    sc.layer.cornerRadius=20;sc.layer.borderWidth=1.0;
    sc.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.08].CGColor;
    [self.view addSubview:sc];
    
    UILabel*stHeader=[UILabel new];stHeader.translatesAutoresizingMaskIntoConstraints=NO;
    stHeader.text=@"🛡️  DEVICE STATUS";
    stHeader.font=[UIFont systemFontOfSize:12 weight:UIFontWeightBlack];
    stHeader.textColor=ZXRed;
    [sc addSubview:stHeader];
    
    UILabel*r1Icon=[UILabel new];r1Icon.translatesAutoresizingMaskIntoConstraints=NO;
    r1Icon.text=@"🍏  iOS";r1Icon.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    r1Icon.textColor=[UIColor colorWithWhite:0.75 alpha:1.0];[sc addSubview:r1Icon];
    
    UILabel*r1Val=[UILabel new];r1Val.translatesAutoresizingMaskIntoConstraints=NO;
    r1Val.text=[UIDevice currentDevice].systemVersion ?: @"18.6.0";
    r1Val.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    r1Val.textColor=UIColor.whiteColor;r1Val.textAlignment=NSTextAlignmentRight;[sc addSubview:r1Val];
    
    UILabel*r2Icon=[UILabel new];r2Icon.translatesAutoresizingMaskIntoConstraints=NO;
    r2Icon.text=@"📱  Device";r2Icon.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    r2Icon.textColor=[UIColor colorWithWhite:0.75 alpha:1.0];[sc addSubview:r2Icon];
    
    NSString *hw = ZXGetHWID();
    NSString *devStr = hw.length > 10 ? [NSString stringWithFormat:@"iPhone13,%@", [hw substringToIndex:1]] : @"iPhone13,1";
    UILabel*r2Val=[UILabel new];r2Val.translatesAutoresizingMaskIntoConstraints=NO;
    r2Val.text=devStr;r2Val.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    r2Val.textColor=UIColor.whiteColor;r2Val.textAlignment=NSTextAlignmentRight;[sc addSubview:r2Val];
    
    UILabel*r3Icon=[UILabel new];r3Icon.translatesAutoresizingMaskIntoConstraints=NO;
    r3Icon.text=@"🟢  Support";r3Icon.font=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    r3Icon.textColor=[UIColor colorWithWhite:0.75 alpha:1.0];[sc addSubview:r3Icon];
    
    UILabel*r3Val=[UILabel new];r3Val.translatesAutoresizingMaskIntoConstraints=NO;
    r3Val.text=@"SUPPORTED";r3Val.font=[UIFont systemFontOfSize:14 weight:UIFontWeightBlack];
    r3Val.textColor=ZXGreen;
    r3Val.textAlignment=NSTextAlignmentRight;[sc addSubview:r3Val];
    
    // Patch options header row
    UILabel*poLeft=[UILabel new];poLeft.translatesAutoresizingMaskIntoConstraints=NO;
    poLeft.text=@"⚡  PATCH OPTIONS";
    poLeft.font=[UIFont systemFontOfSize:12 weight:UIFontWeightBlack];
    poLeft.textColor=ZXRed;
    [self.view addSubview:poLeft];
    
    UILabel*poRight=[UILabel new];poRight.translatesAutoresizingMaskIntoConstraints=NO;
    poRight.text=@"SELECT TO ENABLE";
    poRight.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    poRight.textColor=[UIColor colorWithWhite:0.45 alpha:1.0];
    poRight.textAlignment=NSTextAlignmentRight;
    [self.view addSubview:poRight];
    
    // TableView (2-Column Grid Rows)
    _tv=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tv.translatesAutoresizingMaskIntoConstraints=NO;_tv.backgroundColor=UIColor.clearColor;
    _tv.separatorStyle=UITableViewCellSeparatorStyleNone;
    _tv.dataSource=self;_tv.delegate=self;[self.view addSubview:_tv];
    
    // Bottom Tab Bar
    UIView*tabBar=[[UIView alloc]init];tabBar.translatesAutoresizingMaskIntoConstraints=NO;
    tabBar.backgroundColor=[UIColor colorWithRed:0.04 green:0.05 blue:0.07 alpha:0.98];
    tabBar.layer.borderWidth=0.8;tabBar.layer.borderColor=[UIColor colorWithWhite:1 alpha:.06].CGColor;
    [self.view addSubview:tabBar];
    
    NSMutableArray<UIButton*>*btns=[NSMutableArray array];
    NSArray*tt=@[@"FF Normal",@"FF Max",@"File Status",@"Developer"];
    NSArray*icons=@[@"target",@"flame.fill",@"doc.fill",@"person.fill"];
    for(NSInteger i=0;i<4;i++){
        UIButton*tb=[UIButton buttonWithType:UIButtonTypeSystem];tb.translatesAutoresizingMaskIntoConstraints=NO;
        UIImage *ic = [UIImage systemImageNamed:icons[i]];
        if(!ic) ic = [UIImage systemImageNamed:@"target"];
        [tb setImage:ic forState:0];
        [tb setTitle:tt[i] forState:0];
        tb.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        tb.tintColor=(i==0?ZXRed:[UIColor colorWithWhite:0.45 alpha:1.0]);
        [tb setTitleColor:(i==0?ZXRed:[UIColor colorWithWhite:0.45 alpha:1.0]) forState:0];
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
    
    [NSLayoutConstraint activateConstraints:@[
        [topContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:4],
        [topContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [topContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [topContainer.heightAnchor constraintEqualToConstant:64],
        
        [_headerTabTitle.topAnchor constraintEqualToAnchor:topContainer.topAnchor],
        [_headerTabTitle.centerXAnchor constraintEqualToAnchor:topContainer.centerXAnchor],
        
        [brand.leadingAnchor constraintEqualToAnchor:topContainer.leadingAnchor],
        [brand.topAnchor constraintEqualToAnchor:_headerTabTitle.bottomAnchor constant:2],
        
        [subBrand.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],
        [subBrand.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:2],
        
        [settBtn.trailingAnchor constraintEqualToAnchor:topContainer.trailingAnchor],
        [settBtn.centerYAnchor constraintEqualToAnchor:brand.centerYAnchor],
        [settBtn.widthAnchor constraintEqualToConstant:42],[settBtn.heightAnchor constraintEqualToConstant:42],
        
        [sc.topAnchor constraintEqualToAnchor:topContainer.bottomAnchor constant:10],
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
        
        [_tv.topAnchor constraintEqualToAnchor:poLeft.bottomAnchor constant:8],
        [_tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14],
        [_tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-14],
        [_tv.bottomAnchor constraintEqualToAnchor:tabBar.topAnchor constant:-4],
        
        [tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tabBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [tabBar.heightAnchor constraintEqualToConstant:75],
    ]];
}

-(void)tabTap:(UIButton*)btn{
    _tab=btn.tag;
    NSArray*tt=@[@"FF Normal",@"FF Max",@"File Status",@"Developer"];
    _headerTabTitle.text = tt[_tab];
    
    for(NSInteger i=0;i<4&&i<(NSInteger)_tabBtns.count;i++){
        UIButton*b=_tabBtns[i];
        BOOL isSel = (i==_tab);
        b.tintColor = isSel ? ZXRed : [UIColor colorWithWhite:0.45 alpha:1.0];
        [b setTitleColor:(isSel ? ZXRed : [UIColor colorWithWhite:0.45 alpha:1.0]) forState:0];
    }
    [_tv reloadData];
}

-(void)showSettingsInfo{
    UIAlertController*ac=[UIAlertController alertControllerWithTitle:@"ZEX FREE" message:@"Version 2.7.1\nPort: 9008\nVPS Config Connected" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

// ── VPS Dynamic Injection — JOD BHAI Proven Backend ─────────────────────
-(void)doInject:(ZXSlot*)slot card:(ZXSlotCardView*)card optNum:(NSInteger)opt targetPath:(NSString*)targetPath {
    [card setStatusText:@"Downloading..." color:[UIColor systemYellowColor]];
    
    // Always try server /slot-file endpoint FIRST (proven JOD BHAI approach)
    NSString*autoUrl=[NSString stringWithFormat:@"%@/slot-file/%ld/%ld",kServerBase,(long)opt,(long)slot.slotId];
    NSMutableURLRequest*req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:autoUrl]];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    req.timeoutInterval = 20.0;
    
    NSString*cDir=targetPath;
    NSString*sName=slot.name;
    __weak typeof(card) wc = card;
    __weak typeof(self) ws = self;
    
    void (^handleResult)(NSURL*, NSURLResponse*, NSError*) = ^(NSURL*tmp, NSURLResponse*resp, NSError*err){
        NSHTTPURLResponse*hr=(NSHTTPURLResponse*)resp;
        // Check for download failure FIRST — show error, don't create mock data
        if(!tmp || err || hr.statusCode != 200){
            dispatch_async(dispatch_get_main_queue(),^{
                __strong typeof(wc) scard = wc;
                if(!scard) return;
                scard.isActive = NO;
                if(hr && hr.statusCode != 200){
                    [scard setStatusText:[NSString stringWithFormat:@"Server %ld",(long)hr.statusCode] color:UIColor.systemRedColor];
                } else {
                    [scard setStatusText:@"Download failed" color:UIColor.systemRedColor];
                }
            });
            return;
        }
        
        // File write on background thread (JOD BHAI approach)
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
            // moveItem fallback when NSData is empty (JOD BHAI fallback)
            if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
            ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
        }
        if(!ok){
            // APFS kernel exploit permission fallback
            apfs_own_tree(cDir.UTF8String, 501, 501);
            if(data && data.length > 0){
                ok=[data writeToFile:dest options:NSDataWritingAtomic error:&writeErr];
            } else {
                if([fm fileExistsAtPath:dest])[fm removeItemAtPath:dest error:nil];
                ok=[fm moveItemAtURL:tmp toURL:[NSURL fileURLWithPath:dest] error:&writeErr];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),^{
            __strong typeof(wc) scard = wc;
            __strong typeof(ws) sv = ws;
            if(!scard) return;
            if(ok){
                NSString *relPath = [dest containsString:@"/Documents/"] ? [dest substringFromIndex:[dest rangeOfString:@"/Documents/"].location] : fn;
                [scard setStatusText:[NSString stringWithFormat:@"PATH: %@", relPath] color:ZXGreen];
                if(sv) [sv showPopup:sName path:relPath];
            } else {
                scard.isActive = NO;
                [scard setStatusText:[NSString stringWithFormat:@"Write failed: %@", writeErr.localizedDescription ?: @"Error"] color:UIColor.systemRedColor];
            }
        });
    };
    
    // First try server URL, if fails AND slot.fileUrl exists → retry with that URL
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

-(void)showPopup:(NSString*)name path:(NSString*)path {
    UIWindow*win=[UIApplication sharedApplication].keyWindow;
    CGFloat w=220,h=60;
    UIView*p=[UIView new];p.frame=CGRectMake((win.bounds.size.width-w)/2.0, 52, w, h);
    p.backgroundColor=[UIColor colorWithRed:.04 green:.05 blue:.08 alpha:.96];
    p.layer.cornerRadius=14;
    p.layer.borderWidth=1.2;
    p.layer.borderColor=ZXGreen.CGColor;
    
    UILabel*n=[UILabel new];n.frame=CGRectMake(8,6,w-16,18);
    n.text=[NSString stringWithFormat:@"⚡ %@ INJECTED", name.uppercaseString];
    n.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    n.textColor=UIColor.whiteColor;n.textAlignment=NSTextAlignmentCenter;[p addSubview:n];
    
    UILabel*a=[UILabel new];a.frame=CGRectMake(8,26,w-16,26);
    a.text=[NSString stringWithFormat:@"PATH: %@", path];
    a.font=[UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    a.textColor=ZXGreen;a.numberOfLines=2;a.textAlignment=NSTextAlignmentCenter;[p addSubview:a];
    
    [win addSubview:p];
    p.transform = CGAffineTransformMakeScale(0.8, 0.8);
    p.alpha = 0;
    
    [UIView animateWithDuration:.3 delay:0 usingSpringWithDamping:.7 initialSpringVelocity:.5
        options:0 animations:^{
            p.transform = CGAffineTransformIdentity;
            p.alpha = 1.0;
        }
        completion:^(BOOL f){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                [UIView animateWithDuration:.25 animations:^{
                    p.transform = CGAffineTransformMakeScale(0.8, 0.8);
                    p.alpha=0;
                } completion:^(BOOL ff){[p removeFromSuperview];}];
            });
        }];
}

// ── TableView (2-Column Grid Rows Data Source) ────────────────────────
-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{
    NSArray *slots = self.currentSlots;
    return (NSInteger)ceil(slots.count / 2.0);
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 150.0;
}

-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip{
    ZXGridRowCell*cell=[tv dequeueReusableCellWithIdentifier:@"ZGridCell"];
    if(!cell) cell=[[ZXGridRowCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ZGridCell"];
    
    NSArray *slots = self.currentSlots;
    NSInteger leftIdx = ip.row * 2;
    NSInteger rightIdx = leftIdx + 1;
    
    NSString *subTitle = (_tab==1?@"FREE FIRE • MAX":@"FREE FIRE • NORMAL");
    
    __weak typeof(self) ws = self;
    
    void (^handleCardTap)(ZXSlotCardView *, ZXSlot *) = ^(ZXSlotCardView *card, ZXSlot *slot){
        ZXPlaySound(@"activate");
        __strong typeof(ws) sv = ws;
        if(!sv || !card.isActive) return;
        
        NSString *virtualRoot = [sv mcmBase];
        if([slot.type isEqualToString:@"B"]) {
            virtualRoot = [ZEXFileService.shared.virtualRoot stringByAppendingPathComponent:@"[MHA-C12] System Data"];
        }
        
        BOOL hasTH = slot.ffthPath.length > 0;
        BOOL hasMAX = slot.ffmaxPath.length > 0;
        
        NSString *targetApp = (sv->_tab == 1 || hasMAX) ? @"com.dts.freefiremax" : @"com.dts.freefireth";
        NSString *subPath = (sv->_tab == 1 || hasMAX) ? slot.ffmaxPath : slot.ffthPath;
        
        if([subPath hasPrefix:targetApp]) {
            subPath = [subPath substringFromIndex:targetApp.length];
            if([subPath hasPrefix:@"/"]) subPath = [subPath substringFromIndex:1];
        }
        if(!subPath.length) {
            subPath = @"Documents/contentcache/Compulsory/ios/gameassetbundles/";
        }
        
        NSString *realAppContainer = ZXResolveAppContainerPath(targetApp);
        NSString *p = nil;
        if(realAppContainer.length) {
            p = [realAppContainer stringByAppendingPathComponent:subPath];
        } else {
            NSString *rel = [targetApp stringByAppendingPathComponent:subPath];
            p = [[sv mcmBase] stringByAppendingPathComponent:rel];
        }
        
        if(hasTH && hasMAX) {
            UIAlertController*ac=[UIAlertController alertControllerWithTitle:slot.name message:@"Select target game for injection:" preferredStyle:UIAlertControllerStyleActionSheet];
            [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire TH" style:UIAlertActionStyleDefault handler:^(UIAlertAction*a){
                NSString *realTH = ZXResolveAppContainerPath(@"com.dts.freefireth");
                NSString *sp = realTH.length ? [realTH stringByAppendingPathComponent:slot.ffthPath] : [[sv mcmBase] stringByAppendingPathComponent:slot.ffthPath];
                [sv doInject:slot card:card optNum:sv->_tab+1 targetPath:sp];
            }]];
            [ac addAction:[UIAlertAction actionWithTitle:@"Free Fire MAX" style:UIAlertActionStyleDefault handler:^(UIAlertAction*a){
                NSString *realMAX = ZXResolveAppContainerPath(@"com.dts.freefiremax");
                NSString *sp = realMAX.length ? [realMAX stringByAppendingPathComponent:slot.ffmaxPath] : [[sv mcmBase] stringByAppendingPathComponent:slot.ffmaxPath];
                [sv doInject:slot card:card optNum:sv->_tab+1 targetPath:sp];
            }]];
            [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction*a){
                card.isActive = NO;
            }]];
            [sv presentViewController:ac animated:YES completion:nil];
        } else {
            [sv doInject:slot card:card optNum:sv->_tab+1 targetPath:p];
        }
    };
    
    if (leftIdx < (NSInteger)slots.count) {
        ZXSlot *leftSlot = slots[leftIdx];
        cell.leftCard.hidden = NO;
        [cell.leftCard configureWithSlot:leftSlot subTitle:subTitle];
        cell.leftCard.onTap = ^(ZXSlotCardView *card) {
            handleCardTap(card, leftSlot);
        };
    } else {
        cell.leftCard.hidden = YES;
    }
    
    if (rightIdx < (NSInteger)slots.count) {
        ZXSlot *rightSlot = slots[rightIdx];
        cell.rightCard.hidden = NO;
        [cell.rightCard configureWithSlot:rightSlot subTitle:subTitle];
        cell.rightCard.onTap = ^(ZXSlotCardView *card) {
            handleCardTap(card, rightSlot);
        };
    } else {
        cell.rightCard.hidden = YES;
    }
    
    return cell;
}
@end

// ── ZEXInjectorVC ─────────────────────────────────────────────────
@implementation ZEXInjectorVC
-(UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
-(UIViewController*)childViewControllerForStatusBarStyle{return self.childViewControllers.lastObject;}

-(void)viewDidLoad{
    [super viewDidLoad];
    self.view.frame=UIScreen.mainScreen.bounds;
    self.view.backgroundColor=[UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    [self showLoadingScreen];
}

-(void)showLoadingScreen{
    UIView*loader=[[UIView alloc]initWithFrame:self.view.bounds];
    loader.backgroundColor=[UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    loader.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    UILabel*logo=[UILabel new];logo.translatesAutoresizingMaskIntoConstraints=NO;
    NSMutableAttributedString*as=[[NSMutableAttributedString alloc]initWithString:@"ZEX FREE"];
    [as addAttribute:NSForegroundColorAttributeName value:ZXRed range:NSMakeRange(0,3)];
    [as addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(3,5)];
    [as addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:32 weight:UIFontWeightBlack] range:NSMakeRange(0,8)];
    [as addAttribute:NSKernAttributeName value:@2.5 range:NSMakeRange(0,8)];
    logo.attributedText=as;logo.textAlignment=NSTextAlignmentCenter;
    [loader addSubview:logo];
    
    UILabel*subTitle=[UILabel new];subTitle.translatesAutoresizingMaskIntoConstraints=NO;
    subTitle.text=@"PATCH CONTROL CENTER";
    subTitle.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    subTitle.textColor=ZXRed;subTitle.textAlignment=NSTextAlignmentCenter;
    [loader addSubview:subTitle];
    
    UILabel*sub=[UILabel new];sub.translatesAutoresizingMaskIntoConstraints=NO;
    sub.text=@"> INITIALIZING ZEX FREE INJECTOR...";
    sub.font=[UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    sub.textColor=ZXGreen;sub.textAlignment=NSTextAlignmentCenter;[loader addSubview:sub];
    
    [NSLayoutConstraint activateConstraints:@[
        [logo.centerYAnchor constraintEqualToAnchor:loader.centerYAnchor constant:-30],
        [logo.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        
        [subTitle.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:4],
        [subTitle.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
        
        [sub.topAnchor constraintEqualToAnchor:subTitle.bottomAnchor constant:18],
        [sub.centerXAnchor constraintEqualToAnchor:loader.centerXAnchor],
    ]];
    
    [self.view addSubview:loader];

    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        __strong typeof(ws) sv = ws;
        if(sv) {
            [sv showAuth];
            [UIView animateWithDuration:0.2 animations:^{
                loader.alpha = 0;
            } completion:^(BOOL f){
                [loader removeFromSuperview];
            }];
        }
    });
}

-(void)showAuth{
    for(UIViewController*c in self.childViewControllers){
        [c willMoveToParentViewController:nil];
        [c.view removeFromSuperview];
        [c removeFromParentViewController];
    }
    ZXAuthVC*a=[ZXAuthVC new];
    __weak typeof(self) ws=self;
    a.onAuth=^{[ws showMain];};
    [self addChildViewController:a];
    a.view.frame=self.view.bounds;
    a.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:a.view];
    [a didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}

-(void)showMain{
    for(UIViewController*c in self.childViewControllers){
        [c willMoveToParentViewController:nil];
        [c.view removeFromSuperview];
        [c removeFromParentViewController];
    }
    ZXMainVC*m=[ZXMainVC new];
    [self addChildViewController:m];
    m.view.frame=self.view.bounds;
    m.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:m.view];
    [m didMoveToParentViewController:self];
    [self setNeedsStatusBarAppearanceUpdate];
}
@end
