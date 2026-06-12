ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:12.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VCAMBypass
VCAMBypass_FILES = Tweak.xm
VCAMBypass_CFLAGS = -fobjc-arc
VCAMBypass_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
