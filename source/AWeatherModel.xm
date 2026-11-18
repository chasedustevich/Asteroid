#include "AWeatherModel.h"

@implementation AWeatherModel {
    NSBundle *_weatherBundle;
}

- (instancetype)init {
    if (self = [super init]) {
        _hasFallenBack = YES;
        _populated = NO;
    }
    return self;
}

+ (instancetype)sharedInstance {
    static AWeatherModel *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AWeatherModel alloc] init];
    });
    return sharedInstance;
}

- (void)updateWeatherDataWithCompletion:(completion)compBlock {
    FLOG(@"updateWeatherDataWithCompletion");
    @try {
        Class prefsClass = objc_getClass("WeatherPreferences");
        Class todayModelClass = objc_getClass("WATodayModel");
        if (!prefsClass || !todayModelClass) {
            [self handleDefault];
            [self postNotification];
            if (compBlock) compBlock();
            return;
        }

        self.weatherPreferences = [prefsClass sharedPreferences];
        if ([todayModelClass respondsToSelector:@selector(autoupdatingLocationModelWithPreferences:effectiveBundleIdentifier:)]) {
            self.todayModel = [todayModelClass autoupdatingLocationModelWithPreferences:self.weatherPreferences effectiveBundleIdentifier:@"com.apple.weather"];
        }

        if (!self.todayModel) {
            [self handleDefault];
            [self postNotification];
            if (compBlock) compBlock();
            return;
        }

        if ([self.todayModel respondsToSelector:@selector(setLocationServicesActive:)]) {
            [self.todayModel setLocationServicesActive:YES];
        }
        if ([self.todayModel respondsToSelector:@selector(setIsLocationTrackingEnabled:)]) {
            [self.todayModel setIsLocationTrackingEnabled:YES];
        }

        [self.todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    if (!error && self.todayModel.forecastModel.city) {
                        FLOG(@"successfully, no error when updating");
                        self.forecastModel = self.todayModel.forecastModel;
                        self.city = self.forecastModel.city;
                        [self verifyAndCorrectCondition];
                        self.localWeather = self.city.isLocalWeatherCity;
                        self.populated = YES;
                        self.hasFallenBack = NO;
                    } else {
                        [self handleDefault];
                    }
                    [self postNotification];
                    if (compBlock) compBlock();
                    if ([self.todayModel respondsToSelector:@selector(setIsLocationTrackingEnabled:)]) {
                        [self.todayModel setIsLocationTrackingEnabled:NO];
                    }
                } @catch (NSException *e) {
                    NSLog(@"[Asteroid] Exception in weather model completion: %@", e);
                }
            });
        }];
    } @catch (NSException *e) {
        NSLog(@"[Asteroid] Exception in updateWeatherDataWithCompletion: %@", e);
        [self handleDefault];
        [self postNotification];
        if (compBlock) compBlock();
    }
}

- (void)setUpRefreshTimer {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setUpRefreshTimer];
        });
        return;
    }
    if (!self.refreshTimer) {
        double rate = [prefs doubleForKey:@"refreshRate"];
        if (rate < 30.0) {
            rate = 300.0;
            [prefs setObject:@(300) forKey:@"refreshRate"];
            [prefs save];
        }
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:rate
                                                             target:self
                                                           selector:@selector(updateWeather:)
                                                           userInfo:nil
                                                            repeats:YES];
    }
}

- (void)updateWeather:(NSTimer *)sender {
    [self updateWeatherDataWithCompletion:nil];
}

- (void)postNotification {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self postNotification];
        });
        return;
    }
    FLOG(@"Populated: %lu Fallback: %lu City: %@", (unsigned long)self.isPopulated, (unsigned long)self.hasFallenBack, self.city);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"weatherTimerUpdate" object:nil];
}

- (void)handleDefault {
    @try {
        Class prefsClass = objc_getClass("WeatherPreferences");
        Class todayModelClass = objc_getClass("WATodayModel");
        WeatherPreferences *sharedPrefs = self.weatherPreferences ?: [prefsClass sharedPreferences];
        City *resolvedCity = nil;

        NSInteger defaultIndex = [prefs intForKey:@"astDefaultIndex"];
        if (defaultIndex < 0) defaultIndex = 0;

        if ([sharedPrefs respondsToSelector:@selector(loadSavedCities)]) {
            NSArray *savedCities = [sharedPrefs loadSavedCities];
            if ([savedCities isKindOfClass:[NSArray class]] && savedCities.count > 0) {
                NSUInteger idx = (NSUInteger)defaultIndex < savedCities.count ? (NSUInteger)defaultIndex : 0;
                resolvedCity = savedCities[idx];
            }
        }

        if (!resolvedCity && [prefsClass respondsToSelector:@selector(userDefaultsPersistence)]) {
            id persistence = [prefsClass userDefaultsPersistence];
            NSDictionary *defaultsDict = [persistence respondsToSelector:@selector(userDefaults)] ? [persistence userDefaults] : nil;
            NSArray *cities = [defaultsDict isKindOfClass:[NSDictionary class]] ? defaultsDict[@"Cities"] : nil;
            if ([cities isKindOfClass:[NSArray class]] && cities.count > 0) {
                NSUInteger idx = (NSUInteger)defaultIndex < cities.count ? (NSUInteger)defaultIndex : 0;
                if ([sharedPrefs respondsToSelector:@selector(cityFromPreferencesDictionary:)]) {
                    resolvedCity = [sharedPrefs cityFromPreferencesDictionary:cities[idx]];
                }
            }
        }

        if (!resolvedCity && [sharedPrefs respondsToSelector:@selector(localWeatherCity)]) {
            resolvedCity = [sharedPrefs localWeatherCity];
        }

        if (resolvedCity) {
            self.city = resolvedCity;
            [self verifyAndCorrectCondition];
            self.localWeather = self.city.isLocalWeatherCity;
            if (self.city.wfLocation && [todayModelClass respondsToSelector:@selector(modelWithLocation:)]) {
                self.todayModel = [todayModelClass modelWithLocation:self.city.wfLocation];
                [self.todayModel executeModelUpdateWithCompletion:^(BOOL arg1, NSError *err) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.todayModel.forecastModel) {
                            self.forecastModel = self.todayModel.forecastModel;
                            if (self.forecastModel.city) {
                                self.city = self.forecastModel.city;
                            }
                        }
                    });
                }];
            }
            self.populated = YES;
            self.hasFallenBack = NO;
            return;
        }

        // Synthesize a safe fallback City so animations and views never encounter nil
        Class cityClass = objc_getClass("City");
        if (cityClass && !self.city) {
            City *fallbackCity = [[cityClass alloc] init];
            NSCalendar *cal = [NSCalendar currentCalendar];
            NSInteger hour = [cal component:NSCalendarUnitHour fromDate:[NSDate date]];
            BOOL isDay = (hour >= 6 && hour < 19);
            if ([fallbackCity respondsToSelector:@selector(setIsDay:)]) {
                fallbackCity.isDay = isDay;
            }
            if ([fallbackCity respondsToSelector:@selector(setConditionCode:)]) {
                fallbackCity.conditionCode = [prefs boolForKey:@"customCondition"] ? (long long)[prefs doubleForKey:@"weatherConditions"] : (isDay ? 32 : 31);
            }
            if ([fallbackCity respondsToSelector:@selector(setName:)]) {
                fallbackCity.name = @"Weather";
            }
            self.city = fallbackCity;
        }
        self.populated = (self.city != nil);
        self.hasFallenBack = YES;
    } @catch (NSException *e) {
        NSLog(@"[Asteroid] Exception in handleDefault: %@", e);
        self.hasFallenBack = YES;
    }
}

- (void)verifyAndCorrectCondition {
    if (!self.city) return;
    @try {
        NSInteger conditionCode = [self.city conditionCode];
        Class loaderClass = objc_getClass("WeatherImageLoader");
        NSString *conditionImageName = nil;
        if (conditionCode < 3200 && [loaderClass respondsToSelector:@selector(conditionImageNameWithConditionIndex:)]) {
            conditionImageName = [loaderClass conditionImageNameWithConditionIndex:conditionCode];
        }
        ConditionImageType type = [self conditionImageTypeForString:conditionImageName];

        if (conditionCode == 7) {
            self.city.conditionCode = 6;
        }

        if (conditionCode == 44 ||
            conditionCode == 30 ||
            conditionCode == 29 ||
            conditionCode == 34 ||
            conditionCode == 33 ||
            conditionCode == 32 ||
            conditionCode == 31 ||
            conditionCode == 28 ||
            conditionCode == 27) {
            if (self.city.isDay && type == ConditionImageTypeNight) {
                self.city.conditionCode++;
            } else if (!self.city.isDay && type == ConditionImageTypeDay) {
                if (conditionCode == 44) {
                    self.city.conditionCode = 29;
                } else {
                    self.city.conditionCode--;
                }
            }
        }
    } @catch (NSException *e) {}
}

- (UIImage *)imageForKey:(NSString *)key {
    if (!key || ![key isKindOfClass:[NSString class]] || key.length == 0) {
        return nil;
    }
    @try {
        return [UIImage imageNamed:key inBundle:[self weatherBundle] compatibleWithTraitCollection:nil];
    } @catch (NSException *e) {
        return nil;
    }
}

- (NSBundle *)weatherBundle {
    if (!_weatherBundle) {
        _weatherBundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Weather.framework"];
        [_weatherBundle load];
    }
    return _weatherBundle;
}

- (NSString *)localeTemperature {
    if (!self.hasFallenBack && self.city && [self.city respondsToSelector:@selector(temperature)] && self.city.temperature) {
        BOOL isCelsius = (self.weatherPreferences && [self.weatherPreferences respondsToSelector:@selector(isCelsius)]) ? [self.weatherPreferences isCelsius] : NO;
        double tempVal = isCelsius ? self.city.temperature.celsius : self.city.temperature.fahrenheit;
        return [NSString stringWithFormat:@"%.0f°", tempVal];
    }
    return @"--";
}

- (NSString *)currentConditionOverview {
    if (!self.hasFallenBack && self.city && [self.city respondsToSelector:@selector(naturalLanguageDescription)]) {
        NSString *desc = [self.city naturalLanguageDescription];
        if (desc.length > 0) {
            return desc;
        }
    }
    return @"Weather Unavailable";
}

static UIImage *sfSymbolForConditionCode(NSInteger code, BOOL isDay, ConditionOption option) {
    if (@available(iOS 13.0, *)) {
        NSString *symbol = @"sun.max.fill";
        switch (code) {
            case 0: symbol = @"tornado"; break;
            case 1: case 2: symbol = @"tropicalstorm"; break;
            case 3: case 4: case 37: case 38: case 39: case 45: case 47:
                symbol = isDay ? @"cloud.sun.bolt.fill" : @"cloud.moon.bolt.fill"; break;
            case 5: case 6: case 7: case 35:
                symbol = @"cloud.sleet.fill"; break;
            case 8: case 9: case 10: case 11: case 12:
                symbol = @"cloud.rain.fill"; break;
            case 13: case 14: case 15: case 16: case 41: case 42: case 43: case 46:
                symbol = @"snowflake"; break;
            case 17: case 18: symbol = @"cloud.hail.fill"; break;
            case 19: case 20: case 21: case 22: symbol = @"sun.haze.fill"; break;
            case 23: case 24: symbol = @"wind"; break;
            case 25: symbol = @"thermometer.snowflake"; break;
            case 26: symbol = @"cloud.fill"; break;
            case 27: case 29: symbol = @"cloud.moon.fill"; break;
            case 28: case 30: symbol = @"cloud.sun.fill"; break;
            case 31: symbol = @"moon.stars.fill"; break;
            case 32: case 34: symbol = isDay ? @"sun.max.fill" : @"moon.stars.fill"; break;
            case 33: symbol = @"moon.fill"; break;
            case 36: symbol = @"sun.max.fill"; break;
            default: symbol = isDay ? @"sun.max.fill" : @"moon.stars.fill"; break;
        }
        UIImage *img = [UIImage systemImageNamed:symbol];
        if (img) {
            UIColor *tint = (option == ConditionOptionBlack) ? [UIColor blackColor] : [UIColor whiteColor];
            img = [img imageWithTintColor:tint renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        return img;
    }
    return nil;
}

- (UIImage *)glyphWithOption:(ConditionOption)option {
    NSInteger conditionCode = self.city ? [self.city conditionCode] : 32;
    BOOL isDay = self.city ? self.city.isDay : YES;

    Class loaderClass = objc_getClass("WeatherImageLoader");
    NSString *conditionImageName = nil;
    if (conditionCode < 3200 && [loaderClass respondsToSelector:@selector(conditionImageNameWithConditionIndex:)]) {
        conditionImageName = [loaderClass conditionImageNameWithConditionIndex:conditionCode];
    }

    UIImage *resultImage = nil;
    if (conditionImageName.length > 0) {
        ConditionImageType type = [self conditionImageTypeForString:conditionImageName];
        NSString *rootName = nil;

        switch (type) {
            case ConditionImageTypeDefault: {
                if (option == ConditionOptionDefault) {
                    resultImage = [self imageForKey:[conditionImageName stringByAppendingString:@"-nc"]];
                } else if (option == ConditionOptionWhite) {
                    resultImage = [self imageForKey:[conditionImageName stringByAppendingString:@"-white"]];
                } else if (option == ConditionOptionBlack) {
                    resultImage = [self imageForKey:[conditionImageName stringByAppendingString:@"-black"]];
                }
            } break;

            case ConditionImageTypeDay: {
                if ([conditionImageName containsString:@"thunderstorm"]) {
                    rootName = [[conditionImageName stringByReplacingOccurrencesOfString:@"-" withString:@"_"] stringByReplacingOccurrencesOfString:@"_day" withString:@""];
                } else {
                    rootName = [[conditionImageName stringByReplacingOccurrencesOfString:@"-day" withString:@""] stringByReplacingOccurrencesOfString:@"_day" withString:@""];
                }

                if (option == ConditionOptionDefault) {
                    resultImage = [self imageForKey:[rootName stringByAppendingString:@"_day-nc"]] ?:
                                  [self imageForKey:[rootName stringByAppendingString:@"-day-nc"]];
                } else if (option == ConditionOptionWhite) {
                    resultImage = [self imageForKey:[rootName stringByAppendingString:@"_day-white"]] ?:
                                  [self imageForKey:[rootName stringByAppendingString:@"-day-white"]];
                } else if (option == ConditionOptionBlack) {
                    resultImage = [self imageForKey:[rootName stringByAppendingString:@"_day-black"]] ?:
                                  [self imageForKey:[rootName stringByAppendingString:@"-day-black"]];
                }
            } break;

            case ConditionImageTypeNight: {
                if ([conditionImageName containsString:@"thunderstorm"]) {
                    rootName = [[conditionImageName stringByReplacingOccurrencesOfString:@"-" withString:@"_"] stringByReplacingOccurrencesOfString:@"_night" withString:@""];
                } else {
                    rootName = [[conditionImageName stringByReplacingOccurrencesOfString:@"-night" withString:@""] stringByReplacingOccurrencesOfString:@"_night" withString:@""];
                }

                if (option == ConditionOptionDefault) {
                    resultImage = [self imageForKey:[rootName stringByAppendingString:@"_night-nc"]] ?:
                                  [self imageForKey:[rootName stringByAppendingString:@"-night-nc"]];
                } else if (option == ConditionOptionWhite) {
                    resultImage = [self imageForKey:[rootName stringByAppendingString:@"_night-white"]] ?:
                                  [self imageForKey:[rootName stringByAppendingString:@"-night-white"]];
                } else if (option == ConditionOptionBlack) {
                    resultImage = [self imageForKey:[rootName stringByAppendingString:@"_night-black"]] ?:
                                  [self imageForKey:[rootName stringByAppendingString:@"-night-black"]];
                }
            } break;
        }
    }

    if (!resultImage) {
        resultImage = sfSymbolForConditionCode(conditionCode, isDay, option);
    }
    return resultImage;
}

- (ConditionImageType)conditionImageTypeForString:(NSString *)conditionString {
    if (!conditionString || ![conditionString isKindOfClass:[NSString class]]) {
        return ConditionImageTypeDefault;
    }
    if ([conditionString containsString:@"day"]) {
        return ConditionImageTypeDay;
    } else if ([conditionString containsString:@"night"]) {
        return ConditionImageTypeNight;
    }
    return ConditionImageTypeDefault;
}

@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    if ([prefs boolForKey:@"kLWPEnabled"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            AWeatherModel *weatherModel = [%c(AWeatherModel) sharedInstance];
            [weatherModel updateWeatherDataWithCompletion:^{
                [weatherModel setUpRefreshTimer];
            }];
        });
    }
}
%end

%ctor {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        %init();
    }
}
