#import "defaultweather.h"

%group LegacyWeatherCard
%hook WAWeatherCardView
%property (nonatomic, retain) DefaultWeatherView *defaultWeatherView;
- (void)layoutSubviews {
    %orig;
    if (!self.isLocalWeatherCity) {
        [self.defaultWeatherView removeFromSuperview];
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        self.temperatureLabel.hidden = YES;
        int i = 0;
        Class prefsClass = objc_getClass("WeatherPreferences");
        id persistence = [prefsClass respondsToSelector:@selector(userDefaultsPersistence)] ? [prefsClass userDefaultsPersistence] : nil;
        NSDictionary *defaultsDict = [persistence respondsToSelector:@selector(userDefaults)] ? [persistence userDefaults] : nil;
        NSArray *cities = [defaultsDict isKindOfClass:[NSDictionary class]] ? defaultsDict[@"Cities"] : nil;
        if ([cities isKindOfClass:[NSArray class]]) {
            for (NSDictionary *cityInArray in cities) {
                if ([cityInArray isKindOfClass:[NSDictionary class]] && [self.cityName isEqualToString:cityInArray[@"Name"]]) {
                    self.defaultWeatherView = [[DefaultWeatherView alloc] initWithFrame:CGRectMake(screenWidth - 70, 20, 100, 50) index:(NSUInteger)i];
                    [self addSubview:self.defaultWeatherView];
                    break;
                } else {
                    i++;
                }
            }
        }
    } else {
        self.defaultWeatherView.hidden = YES;
        self.temperatureLabel.hidden = NO;
    }
}
%end
%end

%ctor {
    if (%c(WAWeatherCardView)) {
        %init(LegacyWeatherCard);
    }
}
