#include <Asteroid.h>
#import "LiveWeather.h"
#import "LiveWeatherView.h"

@interface SnowBoardThemeLoader : NSObject
+ (CGFloat)customCornerRadius;
@end

@interface SBIconImageView (AsteroidLiveWeather)
@property (nonatomic, retain) LiveWeatherView *astLiveWeatherView;
- (SBIcon *)icon;
- (void)ast_updateLiveWeatherIcon;
@end

%hook SBIconImageView
%property (nonatomic, retain) LiveWeatherView *astLiveWeatherView;

- (void)setIcon:(id)icon location:(id)location animated:(BOOL)animated {
    %orig;
    [self ast_updateLiveWeatherIcon];
}

- (void)layoutSubviews {
    %orig;
    [self ast_updateLiveWeatherIcon];
}

%new
- (void)ast_updateLiveWeatherIcon {
    SBIcon *icon = nil;
    if ([self respondsToSelector:@selector(icon)]) {
        icon = [self icon];
    }
    if (!icon && [self respondsToSelector:@selector(iconView)]) {
        SBIconView *iv = [self iconView];
        if ([iv respondsToSelector:@selector(icon)]) {
            icon = [iv icon];
        }
    }

    NSString *leafId = [icon respondsToSelector:@selector(leafIdentifier)] ? [icon leafIdentifier] : nil;
    if ([leafId isEqualToString:@"com.apple.weather"]) {
        if (!self.astLiveWeatherView) {
            LiveWeatherView *lwv = [[LiveWeatherView alloc] initWithFrame:self.bounds];
            lwv.tag = 55668;
            lwv.userInteractionEnabled = NO;
            lwv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            lwv.clipsToBounds = YES;
            [self addSubview:lwv];
            self.astLiveWeatherView = lwv;
        }
        self.astLiveWeatherView.frame = self.bounds;
        self.astLiveWeatherView.hidden = NO;

        if ([%c(SnowBoardThemeLoader) respondsToSelector:@selector(customCornerRadius)]) {
            self.astLiveWeatherView.layer.cornerRadius = [%c(SnowBoardThemeLoader) customCornerRadius];
        } else {
            self.astLiveWeatherView.layer.cornerRadius = self.bounds.size.width * 0.225;
            if (@available(iOS 13.0, *)) {
                self.astLiveWeatherView.layer.cornerCurve = kCACornerCurveContinuous;
            }
        }
        self.astLiveWeatherView.layer.masksToBounds = YES;
    } else {
        if (self.astLiveWeatherView) {
            self.astLiveWeatherView.hidden = YES;
        }
    }
}
%end

%ctor {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"] &&
        [prefs boolForKey:@"appIcon"] && [prefs boolForKey:@"kLWPEnabled"]) {
        %init();
    }
}
