#include "AsteroidLockScreen.h"
#import <dlfcn.h>

static BOOL isDismissed = NO;
static SBDashBoardMainPageView *mainPageView = nil;
static BOOL isWeatherLocked = NO;

static void ASTCollectAllSubviews(UIView *view, NSMutableArray<UIView *> *outViews) {
    if (!view) return;
    for (UIView *sub in view.subviews) {
        [outViews addObject:sub];
        ASTCollectAllSubviews(sub, outViews);
    }
}

%group LockScreenMainPage
%hook SBDashBoardMainPageView
%property (nonatomic, retain) UIView *weather;
%property (nonatomic, retain) AWeatherModel *weatherModel;
%property (nonatomic, retain) ASTViewController *gestureViewController;

- (void)layoutSubviews {
    %orig;
    SBDashBoardMainPageView *selfView = (SBDashBoardMainPageView *)self;
    if (!selfView.weather) {
        selfView.weather = [[UIView alloc] initWithFrame:CGRectMake(0, 0, selfView.frame.size.width, selfView.frame.size.height)];
        [selfView.weather setUserInteractionEnabled:YES];
        selfView.weather.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [selfView addSubview:selfView.weather];

        UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(buttonPressed:)];
        swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
        [selfView.weather addGestureRecognizer:swipeUp];

        [[NSNotificationCenter defaultCenter] addObserverForName:@"SBBacklightFadeFinishedNotification" object:NULL queue:NULL usingBlock:^(NSNotification *note) {
            isWeatherLocked = NO;
        }];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buttonPressed:) name:@"astDimissButtonPressed" object:nil];
    }

    mainPageView = selfView;

    if (!selfView.gestureViewController) {
        selfView.gestureViewController = [[%c(ASTViewController) alloc] init];
        selfView.gestureViewController.view.frame = selfView.weather.bounds;
        selfView.gestureViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [selfView.weather addSubview:selfView.gestureViewController.view];
    }
}

%new
- (void)buttonPressed:(UIButton *)sender {
    SBDashBoardMainPageView *selfView = (SBDashBoardMainPageView *)self;
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{ selfView.weather.alpha = 0; }
                     completion:^(BOOL finished) {
                         selfView.weather.hidden = YES;
                         selfView.weather.alpha = 1;

                         isDismissed = YES;
                         isWeatherLocked = YES;
                         [[NSNotificationCenter defaultCenter] postNotificationName:@"weatherStateChanged" object:self];
                     }];
}

%new
- (void)hideWeather {
    SBDashBoardMainPageView *selfView = (SBDashBoardMainPageView *)self;
    selfView.weather.hidden = YES;
    isDismissed = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"weatherStateChanged" object:self];
}

%new
- (void)revealWeather:(NSTimer *)sender {
}

%new
- (void)updateWeatherReveal {
    SBDashBoardMainPageView *selfView = (SBDashBoardMainPageView *)self;
    selfView.weather.hidden = NO;
    isDismissed = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"weatherStateChanged" object:self];
}
%end
%end

%hook WATodayHeaderView
- (NSString *)locationName {
    AWeatherModel *wm = [%c(AWeatherModel) sharedInstance];
    NSString *realName = wm.city.name;
    if (!realName) return %orig;
    if ([self respondsToSelector:@selector(_viewControllerForAncestor)]) {
        WAWeatherPlatterViewController *vc = (WAWeatherPlatterViewController *)[self _viewControllerForAncestor];
        if ([vc respondsToSelector:@selector(model)] && vc.model.forecastModel.city) {
            vc.model.forecastModel.city.name = realName;
        }
    }
    return realName;
}
%end

%hook WAWeatherPlatterViewController
- (void)viewWillLayoutSubviews {
    %orig;
    NSMutableArray<UIView *> *allSubs = [NSMutableArray array];
    ASTCollectAllSubviews(self.view, allSubs);
    for (UIView *object in allSubs) {
        if ([object isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)object;
            label.textColor = [UIColor whiteColor];
        }
        if ([object isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *effect = (UIVisualEffectView *)object;
            if ([effect respondsToSelector:@selector(setContentEffects:)]) {
                effect.contentEffects = nil;
            }
        }
    }
    if ([self respondsToSelector:@selector(dividerLineView)] && self.dividerLineView) {
        self.dividerLineView.backgroundColor = [UIColor whiteColor];
    }
}
%end

%hook SBDashBoardIdleTimerProvider
- (instancetype)initWithDelegate:(id)arg1 {
    self = %orig;
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(turnOffAutoLock) name:@"astDisableLock" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(turnOnAutoLock) name:@"astEnableLock" object:nil];
    }
    return self;
}

%new
- (void)turnOffAutoLock {
    if ([self respondsToSelector:@selector(addDisabledIdleTimerAssertionReason:)]) {
        [self addDisabledIdleTimerAssertionReason:@"Asteroid_owo"];
    }
}

%new
- (void)turnOnAutoLock {
    if ([self respondsToSelector:@selector(removeDisabledIdleTimerAssertionReason:)]) {
        [self removeDisabledIdleTimerAssertionReason:@"Asteroid_owo"];
    }
}
%end

%hook SBDashBoardWallpaperEffectView
- (void)layoutSubviews {
    %orig;
    if (mainPageView && [mainPageView respondsToSelector:@selector(_viewControllerForAncestor)]) {
        id vc = [mainPageView _viewControllerForAncestor];
        if ([vc respondsToSelector:@selector(isTransitioning)]) {
            BOOL transitioning = [(SBDashBoardMainPageContentViewController *)vc isTransitioning];
            [self setHidden:transitioning];
        }
    }
}
- (void)setHidden:(BOOL)arg1 {
    BOOL transitioning = arg1;
    if (mainPageView && [mainPageView respondsToSelector:@selector(_viewControllerForAncestor)]) {
        id vc = [mainPageView _viewControllerForAncestor];
        if ([vc respondsToSelector:@selector(isTransitioning)]) {
            transitioning = [(SBDashBoardMainPageContentViewController *)vc isTransitioning];
        }
    }
    %orig(transitioning);
}
%end

%hook NCNotificationPriorityList
- (NSUInteger)count {
    NSUInteger origCount = %orig;
    if (mainPageView && mainPageView.gestureViewController) {
        [mainPageView.gestureViewController updateNotifcationWithText:[NSString stringWithFormat:@"%i", (int)origCount]];
    }
    return origCount;
}
%end

%hook MediaControlsPanelViewController
- (BOOL)isOnScreen {
    BOOL onScreen = %orig;
    if (onScreen && !isDismissed) {
        [mainPageView hideWeather];
        isWeatherLocked = YES;
    }
    return onScreen;
}
%end

%group NotificationListHook
%hook NCNotificationCombinedListViewController
- (id)init {
    self = %orig;
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateViewCollectionWhenDismissed:) name:@"weatherStateChanged" object:nil];
        [self collectionUpdate];
    }
    return self;
}
- (BOOL)hasContent {
    BOOL content = %orig;
    id lsManager = [%c(SBLockScreenManager) sharedInstance];
    id dashBoardViewCont = nil;
    if ([lsManager respondsToSelector:@selector(coverSheetViewController)]) {
        dashBoardViewCont = [lsManager performSelector:@selector(coverSheetViewController)];
    } else if ([lsManager respondsToSelector:@selector(dashBoardViewController)]) {
        dashBoardViewCont = [lsManager performSelector:@selector(dashBoardViewController)];
    }
    BOOL showingMedia = [dashBoardViewCont respondsToSelector:@selector(isShowingMediaControls)] ? [dashBoardViewCont isShowingMediaControls] : NO;
    id mediaController = [%c(SBMediaController) sharedInstance];
    BOOL isPlaying = [mediaController respondsToSelector:@selector(isPlaying)] ? [mediaController isPlaying] : NO;

    if ((content && [prefs boolForKey:@"hideOnNotif"] && !isDismissed) || isPlaying) {
        [mainPageView hideWeather];
    } else if (!isWeatherLocked && isDismissed && !showingMedia && !isPlaying) {
        if ([prefs boolForKey:@"hideOnNotif"] && !content) {
            [mainPageView updateWeatherReveal];
        } else if (![prefs boolForKey:@"hideOnNotif"]) {
            [mainPageView updateWeatherReveal];
        }
    }
    return content;
}
%new
- (void)updateViewCollectionWhenDismissed:(NSNotification *)sender {
    [self collectionUpdate];
}

%new
- (void)collectionUpdate {
    UIViewController *selfVC = (UIViewController *)self;
    if (isDismissed) {
        [UIView animateWithDuration:0.5
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{ selfVC.view.alpha = 1; }
                         completion:^(BOOL finished) {
                             [selfVC.view setUserInteractionEnabled:YES];
                         }];
    } else {
        [UIView animateWithDuration:0.5
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{ selfVC.view.alpha = 0; }
                         completion:^(BOOL finished) {
                             [selfVC.view setUserInteractionEnabled:NO];
                         }];
    }
}
%end
%end

%group LockScreenCoverSheetVC
%hook SBDashBoardViewController
%property (nonatomic, retain) UIVisualEffectView *blurEffectView;

- (void)loadView {
    %orig;
    SBDashBoardViewController *selfVC = (SBDashBoardViewController *)self;
    UIBlurEffect *blurEffect = nil;
    if ([UIBlurEffect respondsToSelector:@selector(effectWithBlurRadius:)]) {
        double radius = [prefs doubleForKey:@"blurAmount"];
        if (radius <= 0) radius = 5.0;
        blurEffect = [UIBlurEffect effectWithBlurRadius:radius];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }
    selfVC.blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    selfVC.blurEffectView.frame = selfVC.view.bounds;
    selfVC.blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if ([prefs boolForKey:@"addBlur"]) {
        UIView *bgView = [selfVC.view respondsToSelector:@selector(backgroundView)] ? [selfVC.view performSelector:@selector(backgroundView)] : selfVC.view;
        if (bgView && selfVC.blurEffectView) {
            [bgView addSubview:selfVC.blurEffectView];
        }
    }
    [[NSNotificationCenter defaultCenter] addObserverForName:@"weatherStateChanged" object:NULL queue:NULL usingBlock:^(NSNotification *note) {
        if (isDismissed) {
            [UIView animateWithDuration:0.5
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{ selfVC.blurEffectView.alpha = 0; }
                             completion:nil];
        } else {
            [UIView animateWithDuration:0.5
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{ selfVC.blurEffectView.alpha = 1; }
                             completion:nil];
        }
    }];
}
%end
%end

%ctor {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"] &&
        [prefs boolForKey:@"kLWPEnabled"] && [prefs boolForKey:@"greetView"]) {
        dlopen("/System/Library/PrivateFrameworks/Weather.framework/Weather", RTLD_LAZY);

        Class mainPageClass = %c(CSMainPageView) ?: %c(SBDashBoardMainPageView);
        if (mainPageClass) {
            %init(LockScreenMainPage, SBDashBoardMainPageView = mainPageClass);
        }
        Class coverSheetVCClass = %c(CSCoverSheetViewController) ?: %c(SBDashBoardViewController);
        if (coverSheetVCClass) {
            %init(LockScreenCoverSheetVC, SBDashBoardViewController = coverSheetVCClass);
        }
        Class notifListClass = %c(NCNotificationStructuredListViewController) ?: %c(NCNotificationCombinedListViewController);
        if (notifListClass) {
            %init(NotificationListHook, NCNotificationCombinedListViewController = notifListClass);
        }
        %init(_ungrouped);
    }
}
