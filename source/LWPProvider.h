#import <UIKit/UIKit.h>

#ifdef LWP_PROVIDER_CLASS_NAME
#define LWPProvider LWP_PROVIDER_CLASS_NAME
#endif

#define prefs [LWPProvider sharedProvider]

@interface LWPProvider : NSObject

+ (instancetype)sharedProvider;

- (BOOL)boolForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback;
- (NSInteger)intForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (float)floatForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (UIColor *)colorForKey:(NSString *)key;
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (void)save;
- (void)saveAndPostNotification;
- (void)reloadPreferences;
- (void)resetToDefaults;

@end
