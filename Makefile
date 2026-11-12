ARCHS = arm64
TARGET = iphone:clang:latest:14.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = KeepAliveSwap
KeepAliveSwap_FILES = Tweak.x
KeepAliveSwap_FRAMEWORKS = UIKit AVFoundation
KeepAliveSwap_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
