#import "LiveWeather.h"
#import "LiveWeatherView.h"
#include "notify.h"
#import "Asteroid.h"
#import <dlfcn.h>

@interface LiveWeatherView ()
@property (nonatomic, retain) WUIWeatherConditionBackgroundView *referenceView;
@property (nonatomic, retain) CAGradientLayer *gradientLayer;
@property (nonatomic, retain) UIView *gradientView;
@property (nonatomic, retain) UIImageView *logo;
@property (nonatomic, retain) UILabel *temp;
- (CAGradientLayer *)gradientFromWeatherGradient:(CAGradientLayer *)weatherGradient;
@end

@implementation LiveWeatherView {
    AWeatherModel *_weatherModel;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        if ([prefs boolForKey:@"customAppColor"]) {
            self.backgroundColor = [prefs colorForKey:@"appColor"];
        } else {
            self.backgroundColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.88 alpha:1.0];
        }
        self.clipsToBounds = YES;

        _weatherModel = [%c(AWeatherModel) sharedInstance];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(weatherNotification:) name:@"weatherTimerUpdate" object:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateWeatherDisplay];
        });
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    if (w <= 0 || h <= 0) return;

    if (self.referenceView) {
        self.referenceView.frame = self.bounds;
    }
    if (self.gradientView) {
        self.gradientView.frame = self.bounds;
    }
    if (self.gradientLayer) {
        self.gradientLayer.frame = self.bounds;
    }
    if (self.logo) {
        CGFloat logoSize = MIN(w, h) * 0.52;
        self.logo.frame = CGRectMake((w - logoSize) / 2.0, h * 0.12, logoSize, logoSize);
    }
    if (self.temp) {
        self.temp.frame = CGRectMake(2.0, h * 0.62, w - 4.0, h * 0.32);
    }
}

- (void)setupTempLabel {
    self.temp = [[UILabel alloc] initWithFrame:CGRectZero];
    self.temp.textColor = [UIColor whiteColor];
    self.temp.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.temp.adjustsFontSizeToFitWidth = YES;
    self.temp.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.temp];
}

- (void)setupLogoView {
    self.logo = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.logo.contentMode = UIViewContentModeScaleAspectFit;
    self.logo.tintColor = [UIColor whiteColor];
    [self addSubview:self.logo];
}

- (void)setupReferenceView {
    Class bgClass = ASTWeatherConditionBackgroundViewClass();
    if (bgClass) {
        self.referenceView = [[bgClass alloc] initWithFrame:self.bounds];
        if (![prefs boolForKey:@"appScreenWeather"]) {
            self.referenceView.hidesConditions = YES;
        }
        self.referenceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.referenceView.clipsToBounds = YES;
        [self addSubview:self.referenceView];
        [self sendSubviewToBack:self.referenceView];
    }

    self.gradientView = [[UIView alloc] initWithFrame:self.bounds];
    self.gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.gradientView.clipsToBounds = YES;
    [self addSubview:self.gradientView];
    [self sendSubviewToBack:self.gradientView];
}

- (void)weatherNotification:(NSNotification *)notification {
    [self updateWeatherDisplay];
}

- (void)updateWeatherDisplay {
    if ([prefs boolForKey:@"appIcon"]) {
        if (!self.isSetup) {
            [self setupTempLabel];
            [self setupLogoView];
            if ([prefs boolForKey:@"appScreenWeatherBackground"]) {
                [self setupReferenceView];
            }
            self.setup = YES;
            [self setNeedsLayout];
        }

        self.temp.text = [_weatherModel localeTemperature] ?: @"--";

        if (_weatherModel.isPopulated) {
            UIImage *icon = [_weatherModel glyphWithOption:ConditionOptionWhite];
            self.logo.image = icon;
        }

        if ([prefs boolForKey:@"appScreenWeatherBackground"] && _weatherModel.isPopulated && self.referenceView) {
            self.referenceView.background.hidesBackground = NO;
            City *backgroundCity = _weatherModel.city;
            if ([prefs boolForKey:@"customConditionIcon"] && backgroundCity) {
                backgroundCity = [backgroundCity cityCopy];
                backgroundCity.conditionCode = [prefs doubleForKey:@"weatherConditionsIcon"];
            }
            if (backgroundCity) {
                [self.referenceView.background setCity:backgroundCity];
            }
            if (![prefs boolForKey:@"appScreenWeather"]) {
                CAGradientLayer *srcGrad = (CAGradientLayer *)self.referenceView.background.gradientLayer;
                if (srcGrad) {
                    if (self.gradientLayer) {
                        [self.gradientLayer removeFromSuperlayer];
                    }
                    self.gradientLayer = [self gradientFromWeatherGradient:srcGrad];
                    self.gradientLayer.frame = self.gradientView.bounds;
                    [self.gradientView.layer insertSublayer:self.gradientLayer atIndex:0];
                }
                self.gradientView.hidden = NO;
                self.referenceView.hidden = YES;
                [[self.referenceView.background condition] pause];
            } else {
                self.gradientView.hidden = YES;
                self.referenceView.hidden = NO;
                [[self.referenceView.background condition] resume];
            }
        }
        [self setNeedsLayout];
    }
}

- (CAGradientLayer *)gradientFromWeatherGradient:(CAGradientLayer *)weatherGradient {
    if (!weatherGradient) return nil;
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.colors = weatherGradient.colors;
    gradientLayer.locations = weatherGradient.locations;
    gradientLayer.type = weatherGradient.type;
    gradientLayer.startPoint = weatherGradient.startPoint;
    gradientLayer.endPoint = weatherGradient.endPoint;
    return gradientLayer;
}
@end
