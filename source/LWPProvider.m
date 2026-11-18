#import "LWPProvider.h"
#import <notify.h>

#if __has_include(<rootless.h>)
#import <rootless.h>
#else
#define ROOT_PATH(path) path
#define ROOT_PATH_NS(path) path
#endif

static NSString *const kDomain = @"com.midnightchips.asteroid";
static NSString *const kPrefsNotification = @"com.midnightchips.asteroid.prefschanged";

@interface LWPProvider ()
@property (nonatomic, strong) NSMutableDictionary *preferences;
@property (nonatomic, strong) NSDictionary *defaults;
@end

@implementation LWPProvider

+ (instancetype)sharedProvider {
    static dispatch_once_t once;
    static LWPProvider *sharedProvider;
    dispatch_once(&once, ^{
        sharedProvider = [[LWPProvider alloc] init];
    });
    return sharedProvider;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadDefaults];
        [self reloadPreferences];
        [self setupDarwinObserver];
    }
    return self;
}

- (void)loadDefaults {
    NSMutableDictionary *baseDefaults = [@{
        @"kLWPEnabled": @YES,
        @"homeScreenWeather": @NO,
        @"lockScreenWeather": @NO,
        @"hideHomeWeatherBackground": @0,
        @"hideLockWeatherBackground": @0,
        @"freezeCondition": @NO,
        @"customCondition": @NO,
        @"weatherConditions": @0,
        @"refreshRate": @300,
        @"astDefaultIndex": @0,
        @"greetView": @NO,
        @"addgreetLabel": @NO,
        @"addDescription": @NO,
        @"addTemp": @NO,
        @"addLogo": @NO,
        @"addDismiss": @NO,
        @"addBlur": @NO,
        @"enableEditingMode": @YES,
        @"foreHeight": @220,
        @"customFont": @NO,
        @"greetingSize": @40,
        @"wDescriptionSize": @20,
        @"tempSize": @50,
        @"dismissButtonSize": @18,
        @"blurAmount": @5,
        @"iconSize": @1,
        @"forecastContViewSize": @1,
        @"appScreenWeatherBackground": @YES,
        @"customAppColor": @"FFFFFF",
        @"textColor": @"FFFFFF",
        @"glyphColor": @"FFFFFF",
        @"noFolders": @NO,
        @"noDock": @NO
    } mutableCopy];

    NSString *bundlePath = ROOT_PATH_NS(@"/Library/PreferenceBundles/Asteroid.bundle/defaults.plist");
    if ([[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
        NSDictionary *fileDefaults = [NSDictionary dictionaryWithContentsOfFile:bundlePath];
        if (fileDefaults) {
            [baseDefaults addEntriesFromDictionary:fileDefaults];
        }
    }
    self.defaults = [baseDefaults copy];
}

- (void)setupDarwinObserver {
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (CFNotificationCallback)darwinNotificationCallback,
        (__bridge CFStringRef)kPrefsNotification,
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}

static void darwinNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    LWPProvider *provider = (__bridge LWPProvider *)observer;
    [provider reloadPreferences];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LWPSettingsChanged" object:nil userInfo:nil];
    });
}

- (void)reloadPreferences {
    NSMutableDictionary *currentPrefs = [NSMutableDictionary dictionary];
    if (self.defaults) {
        [currentPrefs addEntriesFromDictionary:self.defaults];
    }

    CFArrayRef keyList = CFPreferencesCopyKeyList((__bridge CFStringRef)kDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keyList) {
        CFDictionaryRef dict = CFPreferencesCopyMultiple(keyList, (__bridge CFStringRef)kDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (dict) {
            [currentPrefs addEntriesFromDictionary:(__bridge NSDictionary *)dict];
            CFRelease(dict);
        }
        CFRelease(keyList);
    }

    @synchronized(self) {
        self.preferences = currentPrefs;
    }
}

- (void)resetToDefaults {
    [self loadDefaults];
    @synchronized(self) {
        self.preferences = [self.defaults mutableCopy];
    }
    [self saveAndPostNotification];
}

- (id)objectForKey:(NSString *)key {
    if (!key) return nil;
    id val = nil;
    @synchronized(self) {
        val = self.preferences[key];
    }
    if (val != nil) return val;
    return self.defaults[key];
}

- (BOOL)boolForKey:(NSString *)key {
    return [self boolForKey:key fallback:NO];
}

- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id val = [self objectForKey:key];
    if ([val respondsToSelector:@selector(boolValue)]) {
        return [val boolValue];
    }
    return fallback;
}

- (NSInteger)intForKey:(NSString *)key {
    return [self integerForKey:key];
}

- (NSInteger)integerForKey:(NSString *)key {
    id val = [self objectForKey:key];
    if ([val respondsToSelector:@selector(integerValue)]) {
        return [val integerValue];
    }
    return 0;
}

- (double)doubleForKey:(NSString *)key {
    id val = [self objectForKey:key];
    if ([val respondsToSelector:@selector(doubleValue)]) {
        return [val doubleValue];
    }
    return 0.0;
}

- (float)floatForKey:(NSString *)key {
    id val = [self objectForKey:key];
    if ([val respondsToSelector:@selector(floatValue)]) {
        return [val floatValue];
    }
    return 0.0f;
}

- (NSString *)stringForKey:(NSString *)key {
    id val = [self objectForKey:key];
    if ([val isKindOfClass:[NSString class]]) return val;
    return val ? [val description] : @"";
}

- (UIColor *)colorForKey:(NSString *)key {
    id val = [self objectForKey:key];
    if ([val isKindOfClass:[UIColor class]]) return val;
    if ([val isKindOfClass:[NSString class]]) {
        NSString *hexStr = [(NSString *)val stringByReplacingOccurrencesOfString:@"#" withString:@""];
        if ([hexStr containsString:@":"]) {
            NSArray *parts = [hexStr componentsSeparatedByString:@":"];
            hexStr = parts[0];
            CGFloat alpha = parts.count > 1 ? [parts[1] floatValue] : 1.0f;
            unsigned int hexVal = 0;
            if ([[NSScanner scannerWithString:hexStr] scanHexInt:&hexVal]) {
                return [UIColor colorWithRed:((hexVal >> 16) & 0xFF) / 255.0
                                       green:((hexVal >> 8) & 0xFF) / 255.0
                                        blue:(hexVal & 0xFF) / 255.0
                                       alpha:alpha];
            }
        } else {
            unsigned int hexVal = 0;
            if ([[NSScanner scannerWithString:hexStr] scanHexInt:&hexVal]) {
                if (hexStr.length == 8) {
                    return [UIColor colorWithRed:((hexVal >> 24) & 0xFF) / 255.0
                                           green:((hexVal >> 16) & 0xFF) / 255.0
                                            blue:((hexVal >> 8) & 0xFF) / 255.0
                                           alpha:(hexVal & 0xFF) / 255.0];
                }
                return [UIColor colorWithRed:((hexVal >> 16) & 0xFF) / 255.0
                                       green:((hexVal >> 8) & 0xFF) / 255.0
                                        blue:(hexVal & 0xFF) / 255.0
                                       alpha:1.0f];
            }
        }
    }
    return [UIColor whiteColor];
}

- (void)setObject:(id)value forKey:(NSString *)key {
    if (!key) return;
    @synchronized(self) {
        if (value) {
            self.preferences[key] = value;
        } else {
            [self.preferences removeObjectForKey:key];
        }
    }
    CFPreferencesSetValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)kDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

- (void)save {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
}

- (void)saveAndPostNotification {
    [self save];
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kPrefsNotification,
        NULL,
        NULL,
        true
    );
}

@end
