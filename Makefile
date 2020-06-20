include $(THEOS)/makefiles/common.mk

# THEOS_DEVICE_IP = 192.168.11.12
FINALPACKAGE = 1
TWEAK_NAME = CacheClearer

CacheClearer_FILES = Tweak.xm
CacheClearer_FRAMEWORKS = CydiaSubstrate UIKit MobileCoreServices CoreGraphics CoreFoundation Foundation
CacheClearer_PRIVATE_FRAMEWORKS = SpringBoardServices Preferences
CacheClearer_LDFLAGS = -Wl,-segalign,4000

export ARCHS = arm64 arm64e
CacheClearer_ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk

all::
