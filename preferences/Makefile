include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Asteroid
$(BUNDLE_NAME)_FILES = LWPPreferenceController.m ../source/LWPProvider.m
$(BUNDLE_NAME)_INSTALL_PATH = /Library/PreferenceBundles
$(BUNDLE_NAME)_FRAMEWORKS = UIKit CoreGraphics
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(BUNDLE_NAME)_CFLAGS += -fobjc-arc -DLWP_PROVIDER_CLASS_NAME=ASTPrefsLWPProvider -I$(THEOS_PROJECT_DIR)/../source -Wno-deprecated-declarations -Wno-unguarded-availability-new

include $(THEOS_MAKE_PATH)/bundle.mk
