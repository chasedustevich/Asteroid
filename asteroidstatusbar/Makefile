include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AsteroidStatusBar
AsteroidStatusBar_FILES = AsteroidStatusBar.xm ../source/UIImage+ScaledImage.m ../source/LWPProvider.m
AsteroidStatusBar_FRAMEWORKS = UIKit CoreGraphics
AsteroidStatusBar_PRIVATE_FRAMEWORKS = AppSupport
AsteroidStatusBar_CFLAGS += -fobjc-arc -DLWP_PROVIDER_CLASS_NAME=ASTStatusBarLWPProvider -I$(THEOS_PROJECT_DIR)/../source -Wno-deprecated-declarations -Wno-incompatible-pointer-types

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
