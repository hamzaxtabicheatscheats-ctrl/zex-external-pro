TARGET := iphone:clang:17.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = ZEXInjector

ZEXInjector_FILES = \
    main.m \
    AppDelegate.m \
    ZEXInjectorVC.m \
    ZEXFileService.m \
    MCMBridge.m \
    MCMFilzaIntegration.m \
    sandbox_escape.m \
    apfs_own.m \
    kexploit/kexploit_opa334.m \
    kexploit/krw.m \
    kexploit/kutils.m \
    kexploit/offsets.m \
    kexploit/vnode.m

ZEXInjector_CFLAGS = \
    -I$(THEOS_PROJECT_DIR) \
    -I$(THEOS_PROJECT_DIR)/kexploit \
    -fobjc-arc \
    -Wno-everything

ZEXInjector_FRAMEWORKS = UIKit Foundation CoreFoundation Security QuartzCore AVFoundation AudioToolbox ImageIO CoreGraphics
ZEXInjector_LIBRARIES  = z

include $(THEOS_MAKE_PATH)/application.mk
