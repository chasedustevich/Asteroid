include $(THEOS)/makefiles/common.mk

TWEAK_NAME = defaultweather
defaultweather_FILES = $(wildcard *.xm *.m) ../source/LWPProvider.m
defaultweather_FRAMEWORKS = UIKit CoreGraphics
defaultweather_PRIVATE_FRAMEWORKS = AppSupport Weather
defaultweather_CFLAGS += -fobjc-arc -DLWP_PROVIDER_CLASS_NAME=ASTDefaultWeatherLWPProvider -I$(THEOS_PROJECT_DIR)/../source -Wno-deprecated-declarations -Wno-incompatible-pointer-types

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 com.apple.weather"
