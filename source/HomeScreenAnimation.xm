#import "Asteroid.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBApplication.h>
#import "ConditionImageType.h"

@interface SBBacklightController : NSObject
+ (id)sharedInstance;
- (BOOL)screenIsOn;
@end

@interface SBHomeScreenView : UIView
@property (nonatomic, retain) WUIWeatherConditionBackgroundView *referenceView;
@property (nonatomic, retain) AWeatherModel *weatherModel;
@end

@interface SBHomeScreenView (Weather)
- (void)updateView;
- (BOOL)needsUpdateForCondition:(WUIWeatherCondition *)condition;
@end

@interface UIApplication (asteroid)
- (id)_accessibilityFrontMostApplication;
@end

static float deviceVersion = 0.0f;
static WUIWeatherCondition *condition = nil;
static int conditionNumberSet = 0;

static id ASTGetIvarObject(id obj, const char *name) {
    if (!obj || !name) return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar) return nil;
    return object_getIvar(obj, ivar);
}

static BOOL isScreenTurnedOn(void) {
    id manager = [%c(SBLockScreenManager) sharedInstance];
    if (manager) {
        Ivar ivar = class_getInstanceVariable([manager class], "_isScreenOn");
        if (ivar) {
            ptrdiff_t offset = ivar_getOffset(ivar);
            unsigned char *bytes = (unsigned char *)(__bridge void *)manager;
            return (BOOL)(*(bytes + offset));
        }
    }
    id backlight = [%c(SBBacklightController) sharedInstance];
    if (backlight && [backlight respondsToSelector:@selector(screenIsOn)]) {
        return [backlight screenIsOn];
    }
    return YES;
}

static void updateAnimation(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if ([[UIApplication sharedApplication] _accessibilityFrontMostApplication] == nil && isScreenTurnedOn() && ![prefs boolForKey:@"freezeCondition"]) {
        [condition resume];
    } else {
        [condition pause];
    }
}

%group LiveWeather
%hook SBHomeScreenView
%property (nonatomic, retain) WUIWeatherConditionBackgroundView *referenceView;
%property (nonatomic, retain) AWeatherModel *weatherModel;

- (void)layoutSubviews {
    %orig;
    if (!self.referenceView) {
        self.weatherModel = [%c(AWeatherModel) sharedInstance];
        [self updateView];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"weatherTimerUpdate" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(weatherTimer:) name:@"weatherTimerUpdate" object:nil];
    } else {
        self.referenceView.frame = self.bounds;
    }
}

%new
- (void)weatherTimer:(NSNotification *)notification {
    [self updateView];
}

%new
- (void)updateView {
    if (self.weatherModel.isPopulated && [self needsUpdateForCondition:self.referenceView.background.condition]) {
        [self.referenceView removeFromSuperview];

        Class bgClass = ASTWeatherConditionBackgroundViewClass();
        if (!bgClass) return;

        self.referenceView = [[bgClass alloc] initWithFrame:self.bounds];
        if (!self.referenceView) return;

        [self.referenceView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        if ([prefs intForKey:@"hideHomeWeatherBackground"] == 1) {
            self.referenceView.background.hidesBackground = YES;
            self.referenceView.background.condition.hidesConditionBackground = YES;
        } else if ([prefs intForKey:@"hideHomeWeatherBackground"] == 2) {
            self.referenceView.background.hidesBackground = NO;
            self.referenceView.hidesConditions = YES;
        }

        City *backgroundCity = self.weatherModel.city;
        if ([prefs boolForKey:@"customCondition"] && backgroundCity) {
            backgroundCity = [backgroundCity cityCopy];
            backgroundCity.conditionCode = [prefs doubleForKey:@"weatherConditions"];
        }

        if (backgroundCity) {
            [self.referenceView.background setCity:backgroundCity];
        }
        [self.referenceView.background setTag:123];

        if ([prefs boolForKey:@"freezeCondition"]) {
            [[self.referenceView.background condition] pause];
        } else {
            [[self.referenceView.background condition] resume];
        }
        condition = [self.referenceView.background condition];
        self.referenceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.referenceView.clipsToBounds = YES;
        conditionNumberSet = (int)condition.condition;
        [self addSubview:self.referenceView];
        [self sendSubviewToBack:self.referenceView];
    }
}

%new
- (BOOL)needsUpdateForCondition:(WUIWeatherCondition *)cond {
    if (!cond || !self.referenceView) return YES;
    NSInteger conditionCode = cond.condition;
    NSInteger actualCode = [prefs boolForKey:@"customCondition"] ? (NSInteger)[prefs doubleForKey:@"weatherConditions"] : self.weatherModel.city.conditionCode;
    if (conditionCode != actualCode) {
        return YES;
    }
    NSString *conditionLoadedFile = [cond respondsToSelector:@selector(loadedFileName)] ? [cond loadedFileName] : nil;
    ConditionImageType currentType = [self.weatherModel conditionImageTypeForString:conditionLoadedFile];
    ConditionImageType actualType = self.weatherModel.city.isDay ? ConditionImageTypeDay : ConditionImageTypeNight;

    if (currentType != ConditionImageTypeDefault && currentType != actualType) return YES;
    return NO;
}
%end

%hook SBHomeScreenWindow
- (void)becomeKeyWindow {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (const void *)self,
                                        updateAnimation,
                                        CFSTR("com.apple.springboard.screenchanged"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}
%end
%end

@interface SBIconBlurryBackgroundView : UIView
@end

@interface SBFolderIconBackgroundView : SBIconBlurryBackgroundView
@end

%hook SBFolderIconBackgroundView
- (void)layoutSubviews {
    %orig;
    if ([prefs boolForKey:@"noFolders"]) {
        self.hidden = YES;
    } else {
        self.hidden = NO;
    }
}

- (void)setWallpaperBackgroundRect:(CGRect)rect forContents:(CGImageRef)contents withFallbackColor:(CGColorRef)fallbackColor {
    if ([prefs boolForKey:@"noFolders"]) {
        %orig(CGRectNull, NULL, NULL);
        self.backgroundColor = [UIColor clearColor];
    } else {
        %orig;
    }
}
%end

@interface SBDockView : UIView
@end

%hook SBDockView
- (void)layoutSubviews {
    %orig;
    if ([prefs boolForKey:@"noDock"]) {
        UIView *bgView = ASTGetIvarObject(self, "_backgroundView");
        UIView *bgImgView = ASTGetIvarObject(self, "_backgroundImageView");
        UIView *accBgView = ASTGetIvarObject(self, "_accessibilityBackgroundView");
        if ([bgView isKindOfClass:[UIView class]]) bgView.hidden = YES;
        if ([bgImgView isKindOfClass:[UIView class]]) bgImgView.hidden = YES;
        if ([accBgView isKindOfClass:[UIView class]]) accBgView.hidden = YES;
    }
}
%end

@interface SBHighlightView : UIView
@end

%hook SBHighlightView
- (void)layoutSubviews {
    %orig;
    if ([prefs boolForKey:@"noDock"]) {
        self.hidden = YES;
    }
}
%end

%hook City
%new
- (id)cityCopy {
    City *city = [[[%c(City) class] alloc] init];
    if (!city) return self;
    @try {
        if ([self respondsToSelector:@selector(name)] && [city respondsToSelector:@selector(setName:)]) {
            city.name = self.name;
        }
        if ([self respondsToSelector:@selector(conditionCode)] && [city respondsToSelector:@selector(setConditionCode:)]) {
            city.conditionCode = self.conditionCode;
        }
        if ([self respondsToSelector:@selector(isDay)] && [city respondsToSelector:@selector(setIsDay:)]) {
            city.isDay = self.isDay;
        }
        if ([self respondsToSelector:@selector(isLocalWeatherCity)] && [city respondsToSelector:@selector(setIsLocalWeatherCity:)]) {
            city.isLocalWeatherCity = self.isLocalWeatherCity;
        }
        if ([self respondsToSelector:@selector(wfLocation)] && [city respondsToSelector:@selector(setWfLocation:)]) {
            city.wfLocation = self.wfLocation;
        }
        if ([self respondsToSelector:@selector(temperature)]) {
            [city setValue:[self temperature] forKey:@"temperature"];
        }
    } @catch (NSException *e) {}
    return city;
}
%end

%group LegacyWeatherUI
%hook WUIDynamicWeatherBackground
%property (nonatomic, assign) BOOL hidesBackground;
- (id)gradientLayer {
    if (self.hidesBackground) return nil;
    return %orig;
}
- (void)setCurrentBackground:(CALayer *)arg1 {
    if (!self.hidesBackground) {
        %orig;
    }
}
- (void)setBackgroundCache:(NSCache *)arg1 {
    if (!self.hidesBackground) {
        %orig;
    }
}
- (void)addSublayer:(id)arg1 {
    %orig;
    if (deviceVersion < 11.3 && self.hidesBackground) {
        CALayer *layer = arg1;
        for (CALayer *firstLayers in layer.sublayers) {
            if (firstLayers.backgroundColor) {
                firstLayers.backgroundColor = [UIColor clearColor].CGColor;
            }
            for (CALayer *secLayers in firstLayers.sublayers) {
                for (CALayer *thrLayers in secLayers.sublayers) {
                    if ([thrLayers isKindOfClass:[CAGradientLayer class]]) {
                        thrLayers.hidden = YES;
                    }
                }
            }
        }
    }
}
%end

%hook WUIWeatherCondition
%property (nonatomic, assign) BOOL hidesConditionBackground;
- (CALayer *)layer {
    if ((self.alpha == 982 || self.condition == 3) && self.hidesConditionBackground) {
        CALayer *layer = %orig;
        for (CALayer *firstLayers in layer.sublayers) {
            if (firstLayers.backgroundColor) {
                firstLayers.backgroundColor = [UIColor clearColor].CGColor;
            }
            for (CALayer *secLayers in firstLayers.sublayers) {
                for (CALayer *thrLayers in secLayers.sublayers) {
                    if (![thrLayers isKindOfClass:[CAEmitterLayer class]] && ![thrLayers isKindOfClass:[CATransformLayer class]]) {
                        if (thrLayers.backgroundColor) {
                            thrLayers.backgroundColor = [UIColor clearColor].CGColor;
                        }
                    }
                }
            }
        }
    }
    return %orig;
}
%end
%end

%ctor {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"] && [prefs boolForKey:@"kLWPEnabled"]) {
        deviceVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        dlopen("/System/Library/PrivateFrameworks/Weather.framework/Weather", RTLD_LAZY);
        if (deviceVersion < 16.0f) {
            dlopen("/System/Library/PrivateFrameworks/WeatherUI.framework/WeatherUI", RTLD_LAZY);
        }
        if ([prefs boolForKey:@"homeScreenWeather"]) {
            %init(LiveWeather);
        }
        if (%c(WUIDynamicWeatherBackground) && %c(WUIWeatherCondition)) {
            %init(LegacyWeatherUI);
        }
        %init(_ungrouped);
    }
}
