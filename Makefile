export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:15.0
export THEOS_PACKAGE_SCHEME = rootless

FINALPACKAGE = 0
GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Asteroid
Asteroid_FILES = $(wildcard source/*.m source/*.xm source/*.mm source/*.x)
Asteroid_FRAMEWORKS = CoreLocation UIKit CoreGraphics QuartzCore ImageIO
Asteroid_PRIVATE_FRAMEWORKS = Weather AppSupport
Asteroid_CFLAGS += -fobjc-arc -I$(THEOS_PROJECT_DIR)/source

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += preferences
SUBPROJECTS += asteroidlockscreen
SUBPROJECTS += asteroidstatusbar
SUBPROJECTS += defaultweather
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
