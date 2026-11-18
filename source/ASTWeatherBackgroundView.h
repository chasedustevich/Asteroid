#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "WeatherHeaders.h"

@interface ASTWeatherCondition : NSObject
@property (assign, nonatomic) long long condition;
@property (nonatomic, retain) NSString *loadedFileName;
@property (nonatomic) BOOL hidesConditionBackground;
@property (nonatomic, retain) City *city;
@property (nonatomic) BOOL playing;
@property (nonatomic) double alpha;
@property (nonatomic, retain) CALayer *layer;
- (void)pause;
- (void)resume;
@end

@interface ASTDynamicWeatherBackground : UIView
@property (nonatomic) BOOL hidesBackground;
@property (nonatomic) BOOL hidesConditions;
@property (nonatomic, retain) CAGradientLayer *gradientLayer;
@property (nonatomic, retain) City *city;
- (ASTWeatherCondition *)condition;
- (void)setCity:(City *)city;
- (void)setCondition:(long long)conditionCode;
@end

@interface ASTWeatherConditionBackgroundView : UIView
@property (nonatomic) BOOL hidesConditions;
@property (nonatomic, retain) ASTDynamicWeatherBackground *background;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)prepareToSuspend;
- (void)prepareToResume;
@end

#ifdef __cplusplus
extern "C" {
#endif
Class ASTWeatherConditionBackgroundViewClass(void);
#ifdef __cplusplus
}
#endif
