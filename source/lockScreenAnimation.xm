#import "Asteroid.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "ConditionImageType.h"

@interface SBLockScreenManager : NSObject
+ (id)sharedInstance;
@property (readonly) BOOL isUILocked;
@property (readonly) BOOL isLockScreenVisible;
@end

@interface SBBacklightController : NSObject
+ (id)sharedInstance;
- (BOOL)screenIsOn;
@end

@interface CSCoverSheetView : UIView
@property (nonatomic, retain) WUIWeatherConditionBackgroundView *referenceView;
@property (nonatomic, retain) AWeatherModel *weatherModel;
- (void)updateView;
- (BOOL)needsUpdateForCondition:(WUIWeatherCondition *)cond;
@end

@interface CSCoverSheetViewController : UIViewController
@end

@interface City (AsteroidCopy)
- (id)cityCopy;
@end

static NSHashTable<CSCoverSheetView *> *activeCoverSheetViews = nil;

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

static void updateLockScreenAnimationState(void) {
    BOOL screenOn = isScreenTurnedOn();
    BOOL freeze = [prefs boolForKey:@"freezeCondition"];
    for (CSCoverSheetView *csView in [activeCoverSheetViews copy]) {
        if (csView.referenceView) {
            if (screenOn && !freeze) {
                [csView.referenceView prepareToResume];
            } else {
                [csView.referenceView prepareToSuspend];
            }
        }
    }
}

static void screenStateChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        updateLockScreenAnimationState();
    });
}

%group LockScreenCoverSheet
%hook CSCoverSheetView
%property (nonatomic, retain) WUIWeatherConditionBackgroundView *referenceView;
%property (nonatomic, retain) AWeatherModel *weatherModel;

- (void)didMoveToWindow {
    %orig;
    CSCoverSheetView *selfView = (CSCoverSheetView *)self;
    if (selfView.window) {
        if (!activeCoverSheetViews) {
            activeCoverSheetViews = [NSHashTable weakObjectsHashTable];
        }
        if (![activeCoverSheetViews containsObject:selfView]) {
            [activeCoverSheetViews addObject:selfView];
        }
        if (!selfView.weatherModel) {
            selfView.weatherModel = [%c(AWeatherModel) sharedInstance];
        }
        [selfView updateView];
    }
}

- (void)layoutSubviews {
    %orig;
    CSCoverSheetView *selfView = (CSCoverSheetView *)self;
    if (!activeCoverSheetViews) {
        activeCoverSheetViews = [NSHashTable weakObjectsHashTable];
    }
    if (![activeCoverSheetViews containsObject:selfView]) {
        [activeCoverSheetViews addObject:selfView];
    }

    if (!selfView.referenceView) {
        selfView.weatherModel = [%c(AWeatherModel) sharedInstance];
        [selfView updateView];
        [[NSNotificationCenter defaultCenter] removeObserver:selfView name:@"weatherTimerUpdate" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:selfView selector:@selector(weatherTimer:) name:@"weatherTimerUpdate" object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:selfView name:@"LWPSettingsChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:selfView selector:@selector(weatherTimer:) name:@"LWPSettingsChanged" object:nil];
    } else {
        selfView.referenceView.frame = selfView.bounds;
    }
}

%new
- (void)weatherTimer:(NSNotification *)notification {
    CSCoverSheetView *selfView = (CSCoverSheetView *)self;
    [selfView updateView];
}

%new
- (void)updateView {
    CSCoverSheetView *selfView = (CSCoverSheetView *)self;
    if (![prefs boolForKey:@"lockScreenWeather"] || ![prefs boolForKey:@"kLWPEnabled"]) {
        if (selfView.referenceView) {
            [selfView.referenceView removeFromSuperview];
            selfView.referenceView = nil;
        }
        return;
    }

    if (!selfView.weatherModel) {
        selfView.weatherModel = [%c(AWeatherModel) sharedInstance];
    }

    if (selfView.weatherModel.isPopulated && [selfView needsUpdateForCondition:selfView.referenceView.background.condition]) {
        [selfView.referenceView removeFromSuperview];

        Class bgClass = ASTWeatherConditionBackgroundViewClass();
        if (!bgClass) return;

        selfView.referenceView = [[bgClass alloc] initWithFrame:selfView.bounds];
        if (!selfView.referenceView) return;

        [selfView.referenceView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        selfView.referenceView.userInteractionEnabled = NO;

        if ([prefs intForKey:@"hideLockWeatherBackground"] == 1) {
            selfView.referenceView.background.hidesBackground = YES;
            selfView.referenceView.background.condition.hidesConditionBackground = YES;
        } else if ([prefs intForKey:@"hideLockWeatherBackground"] == 2) {
            selfView.referenceView.background.hidesBackground = NO;
            selfView.referenceView.hidesConditions = YES;
        }

        City *backgroundCity = selfView.weatherModel.city;
        if ([prefs boolForKey:@"customCondition"] && backgroundCity) {
            if ([backgroundCity respondsToSelector:@selector(cityCopy)]) {
                backgroundCity = [backgroundCity cityCopy];
            }
            backgroundCity.conditionCode = [prefs doubleForKey:@"weatherConditions"];
        }

        if (backgroundCity) {
            [selfView.referenceView.background setCity:backgroundCity];
        }

        if ([prefs boolForKey:@"freezeCondition"]) {
            [[selfView.referenceView.background condition] pause];
        } else {
            [[selfView.referenceView.background condition] resume];
        }
        selfView.referenceView.clipsToBounds = YES;

        // Insertion into CoverSheet view hierarchy
        UIView *targetBackground = nil;
        if ([selfView respondsToSelector:@selector(backgroundView)]) {
            targetBackground = [selfView performSelector:@selector(backgroundView)];
        }
        if (!targetBackground) {
            Ivar ivar = class_getInstanceVariable([selfView class], "_backgroundView");
            if (ivar) targetBackground = object_getIvar(selfView, ivar);
        }
        if (!targetBackground) {
            Ivar ivar = class_getInstanceVariable([selfView class], "_wallpaperEffectView");
            if (ivar) targetBackground = object_getIvar(selfView, ivar);
        }

        if (targetBackground && [selfView.subviews containsObject:targetBackground]) {
            [selfView insertSubview:selfView.referenceView aboveSubview:targetBackground];
        } else {
            [selfView insertSubview:selfView.referenceView atIndex:0];
        }
    } else if (selfView.referenceView) {
        selfView.referenceView.frame = selfView.bounds;
    }
}

%new
- (BOOL)needsUpdateForCondition:(WUIWeatherCondition *)cond {
    CSCoverSheetView *selfView = (CSCoverSheetView *)self;
    if (!cond || !selfView.referenceView) return YES;
    NSInteger conditionCode = cond.condition;
    NSInteger actualCode = [prefs boolForKey:@"customCondition"] ? (NSInteger)[prefs doubleForKey:@"weatherConditions"] : selfView.weatherModel.city.conditionCode;
    if (conditionCode != actualCode) {
        return YES;
    }
    NSString *conditionLoadedFile = [cond respondsToSelector:@selector(loadedFileName)] ? [cond loadedFileName] : nil;
    ConditionImageType currentType = [selfView.weatherModel conditionImageTypeForString:conditionLoadedFile];
    ConditionImageType actualType = selfView.weatherModel.city.isDay ? ConditionImageTypeDay : ConditionImageTypeNight;

    if (currentType != ConditionImageTypeDefault && currentType != actualType) return YES;
    return NO;
}

- (void)dealloc {
    CSCoverSheetView *selfView = (CSCoverSheetView *)self;
    [[NSNotificationCenter defaultCenter] removeObserver:selfView name:@"weatherTimerUpdate" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:selfView name:@"LWPSettingsChanged" object:nil];
    if (activeCoverSheetViews) {
        [activeCoverSheetViews removeObject:selfView];
    }
    %orig;
}

%end
%end

%group LockScreenCoverSheetVC
%hook CSCoverSheetViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    UIViewController *selfVC = (UIViewController *)self;
    if ([selfVC.view respondsToSelector:@selector(referenceView)]) {
        CSCoverSheetView *csView = (CSCoverSheetView *)selfVC.view;
        if (csView.referenceView) {
            [csView updateView];
            if (![prefs boolForKey:@"freezeCondition"]) {
                [csView.referenceView prepareToResume];
            }
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    UIViewController *selfVC = (UIViewController *)self;
    if ([selfVC.view respondsToSelector:@selector(referenceView)]) {
        CSCoverSheetView *csView = (CSCoverSheetView *)selfVC.view;
        if (csView.referenceView) {
            [csView.referenceView prepareToSuspend];
        }
    }
}

%end
%end

%ctor {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        activeCoverSheetViews = [NSHashTable weakObjectsHashTable];

        Class coverSheetClass = %c(CSCoverSheetView) ?: %c(SBDashBoardView);
        if (coverSheetClass) {
            %init(LockScreenCoverSheet, CSCoverSheetView = coverSheetClass);
        }

        Class coverSheetVCClass = %c(CSCoverSheetViewController) ?: %c(SBDashBoardViewController);
        if (coverSheetVCClass) {
            %init(LockScreenCoverSheetVC, CSCoverSheetViewController = coverSheetVCClass);
        }

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        screenStateChangedCallback,
                                        CFSTR("com.apple.springboard.screenchanged"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
