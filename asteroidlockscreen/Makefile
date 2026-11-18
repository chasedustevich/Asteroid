include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AsteroidLockScreen
AsteroidLockScreen_FILES = $(wildcard *.xm *.m *.mm) ../source/LWPProvider.m
AsteroidLockScreen_FRAMEWORKS = CoreLocation UIKit CoreGraphics QuartzCore AudioToolbox
AsteroidLockScreen_PRIVATE_FRAMEWORKS = Weather
AsteroidLockScreen_CFLAGS += -fobjc-arc -DLWP_PROVIDER_CLASS_NAME=ASTLockScreenLWPProvider -I$(THEOS_PROJECT_DIR)/../source -Wno-deprecated-declarations -Wno-enum-compare -Wno-incompatible-pointer-types

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
