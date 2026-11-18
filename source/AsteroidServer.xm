#include <AppSupport/CPDistributedMessagingCenter.h>
#import "AWeatherModel.h"
#import "LWPProvider.h"
#import <dlfcn.h>

@interface AsteroidServer : NSObject
@property (nonatomic, retain) AWeatherModel *weatherModel;
@end

@implementation AsteroidServer

+ (id)sharedInstance {
    static dispatch_once_t once = 0;
    __strong static id sharedInstance = nil;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    if ((self = [super init])) {
        self.weatherModel = [%c(AWeatherModel) sharedInstance];

        // Only start CPDistributedMessagingCenter if RocketBootstrap is loaded
        void (*rb_apply)(id) = (void (*)(id))dlsym(RTLD_DEFAULT, "rocketbootstrap_distributedmessagingcenter_apply");
        if (rb_apply) {
            @try {
                CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"com.midnightchips.AsteroidServer"];
                rb_apply(messagingCenter);
                [messagingCenter runServerOnCurrentThread];

                [messagingCenter registerForMessageName:@"weatherIcon" target:self selector:@selector(returnWeatherLogo)];
                [messagingCenter registerForMessageName:@"weatherTemp" target:self selector:@selector(returnWeatherTemp)];
                [messagingCenter registerForMessageName:@"weatherItems" target:self selector:@selector(returnWeatherItems)];
                [messagingCenter registerForMessageName:@"cityIndex" target:self selector:@selector(returnCurrentIndex)];
                [messagingCenter registerForMessageName:@"returnCityIndex" target:self selector:@selector(saveCurrentIndexName:withUserInfo:)];
            } @catch (NSException *e) {
                NSLog(@"[AsteroidServer] Warning: Could not initialize CPDistributedMessagingCenter: %@", e);
            }
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWeatherUpdate:) name:@"weatherTimerUpdate" object:nil];
    }
    return self;
}

- (void)onWeatherUpdate:(NSNotification *)note {
    @try {
        NSString *temp = [self returnWeatherTempString];
        NSData *iconData = [self returnWeatherLogoData];
        if (temp) [prefs setObject:temp forKey:@"cachedWeatherTemp"];
        if (iconData) [prefs setObject:iconData forKey:@"cachedWeatherIconData"];
        [prefs save];
    } @catch (NSException *e) {}
}

- (NSDictionary *)returnWeatherItems {
    NSMutableDictionary *sendItems = [[NSMutableDictionary alloc] init];
    NSString *temp = [self returnWeatherTempString];
    NSData *data = [self returnWeatherLogoData];
    if (temp) sendItems[@"temp"] = temp;
    if (data) sendItems[@"image"] = data;
    return sendItems;
}

- (NSData *)returnWeatherLogoData {
    UIImage *glyph = [self.weatherModel glyphWithOption:ConditionOptionDefault];
    if (glyph) {
        return UIImagePNGRepresentation(glyph);
    }
    return nil;
}

- (UIImage *)returnWeatherLogoImage {
    return [self.weatherModel glyphWithOption:ConditionOptionDefault];
}

- (NSString *)returnWeatherTempString {
    return [self.weatherModel localeTemperature] ?: @"--";
}

- (NSDictionary *)returnWeatherLogo {
    NSMutableDictionary *sendImage = [[NSMutableDictionary alloc] init];
    NSData *imageData = [self returnWeatherLogoData];
    if (imageData) {
        sendImage[@"image"] = imageData;
    }
    return sendImage;
}

- (NSDictionary *)returnWeatherTemp {
    NSMutableDictionary *sendTemp = [[NSMutableDictionary alloc] init];
    NSString *temp = [self returnWeatherTempString];
    if (temp) {
        sendTemp[@"temp"] = temp;
    }
    return sendTemp;
}

- (NSDictionary *)returnCurrentIndex {
    NSMutableDictionary *sendIndex = [[NSMutableDictionary alloc] init];
    sendIndex[@"index"] = @([prefs intForKey:@"astDefaultIndex"]);
    return sendIndex;
}

- (void)saveCurrentIndexName:(NSString *)name withUserInfo:(NSDictionary *)indexDict {
    NSNumber *indexValue = indexDict[@"index"];
    if (indexValue) {
        [prefs setObject:indexValue forKey:@"astDefaultIndex"];
        [prefs saveAndPostNotification];
    }
}
@end

%ctor {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"] && [prefs boolForKey:@"kLWPEnabled"]) {
        [AsteroidServer sharedInstance];
    }
}
