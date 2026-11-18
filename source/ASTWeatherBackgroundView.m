#import "ASTWeatherBackgroundView.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

#if __has_include(<rootless.h>)
#import <rootless.h>
#else
#define ROOT_PATH(path) path
#define ROOT_PATH_NS(path) path
#endif

@interface CAMLParser : NSObject
+ (id)parser;
- (void)setDelegate:(id)delegate;
- (void)setBaseURL:(NSURL *)url;
- (BOOL)parseData:(NSData *)data;
- (BOOL)parseBytes:(const char *)bytes length:(size_t)length;
- (id)result;
@end

@interface CAStateController : NSObject
- (instancetype)initWithLayer:(CALayer *)layer;
- (void)setInitialStatesOfLayer:(CALayer *)layer;
@end

@interface ASTCAMLParserDelegate : NSObject
@property (nonatomic, strong) NSCache *resourceCache;
+ (instancetype)sharedDelegate;
@end

@implementation ASTCAMLParserDelegate

+ (instancetype)sharedDelegate {
    static ASTCAMLParserDelegate *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[ASTCAMLParserDelegate alloc] init];
    });
    return shared;
}

- (instancetype)init {
    if (self = [super init]) {
        _resourceCache = [[NSCache alloc] init];
        _resourceCache.countLimit = 128;
    }
    return self;
}

- (id)CAMLParser:(id)parser resourceForURL:(NSURL *)url {
    if (!url) return nil;
    NSString *fileName = [url lastPathComponent];
    if (fileName.length == 0) return nil;

    id cached = [_resourceCache objectForKey:fileName];
    if (cached) {
        return cached;
    }

    NSString *bundledMicaDir = ROOT_PATH_NS(@"/Library/Application Support/Asteroid/Mica");
    NSArray<NSString *> *candidatePaths = @[
        [bundledMicaDir stringByAppendingPathComponent:fileName],
        [bundledMicaDir stringByAppendingPathComponent:[@"assets" stringByAppendingPathComponent:fileName]],
        [@"/System/Library/PrivateFrameworks/WeatherUI.framework/Mica/" stringByAppendingPathComponent:fileName],
        [@"/System/Library/PrivateFrameworks/WeatherUI.framework/Mica/assets/" stringByAppendingPathComponent:fileName],
        [@"/System/Library/PrivateFrameworks/WeatherUI.framework/" stringByAppendingPathComponent:fileName],
        [@"/System/Library/PrivateFrameworks/Weather.framework/Mica/" stringByAppendingPathComponent:fileName],
        [@"/System/Library/PrivateFrameworks/Weather.framework/" stringByAppendingPathComponent:fileName]
    ];

    NSData *imgData = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in candidatePaths) {
        if ([fm fileExistsAtPath:path]) {
            imgData = [NSData dataWithContentsOfFile:path];
            if (imgData.length > 0) break;
        }
    }

    if (!imgData) {
        NSBundle *wuBundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/WeatherUI.framework"];
        NSString *name = [fileName stringByDeletingPathExtension];
        NSString *ext = [fileName pathExtension];
        NSURL *resURL = [wuBundle URLForResource:name withExtension:ext subdirectory:@"Mica"]
                     ?: [wuBundle URLForResource:name withExtension:ext subdirectory:nil];
        if (resURL) {
            imgData = [NSData dataWithContentsOfURL:resURL];
        }
    }

    if (imgData.length > 0) {
        CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)imgData, NULL);
        if (src) {
            NSDictionary *opts = @{ (__bridge NSString *)kCGImageSourceShouldCache : @YES };
            CGImageRef cgImg = CGImageSourceCreateImageAtIndex(src, 0, (__bridge CFDictionaryRef)opts);
            CFRelease(src);
            if (cgImg) {
                id obj = (__bridge id)cgImg;
                [_resourceCache setObject:obj forKey:fileName];
                CGImageRelease(cgImg);
                return obj;
            }
        }
    }
    return nil;
}

- (void)CAMLParser:(id)parser didLoadResource:(id)resource fromURL:(NSURL *)url {
    NSString *fileName = [url lastPathComponent];
    if (resource && fileName.length > 0) {
        [_resourceCache setObject:resource forKey:fileName];
    }
}

- (Class)CAMLParser:(id)parser didFailToFindClassWithName:(NSString *)name {
    if (!name) return nil;
    static NSDictionary<NSString *, NSString *> *classMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classMap = @{
            @"LKState": @"CAState",
            @"LKStateAddAnimation": @"CAStateAddAnimation",
            @"LKStateAddElement": @"CAStateAddElement",
            @"LKStateElement": @"CAStateElement",
            @"LKStateRemoveAnimation": @"CAStateRemoveAnimation",
            @"LKStateRemoveElement": @"CAStateRemoveElement",
            @"LKStateSetValue": @"CAStateSetValue",
            @"LKStateTransition": @"CAStateTransition",
            @"LKStateTransitionElement": @"CAStateTransitionElement",
            @"LKEventHandler": @"CAEventHandler"
        };
    });
    NSString *mapped = classMap[name];
    if (mapped) {
        return objc_getClass([mapped UTF8String]);
    }
    return nil;
}

- (void)CAMLParser:(id)parser formatWarningString:(const char *)str arguments:(va_list)args lineNumber:(unsigned long)line {
}

- (void)CAMLParser:(id)parser formatErrorString:(const char *)str arguments:(va_list)args lineNumber:(unsigned long)line {
}

@end

static NSString *ASTCAMLBaseNameForCondition(long long code, BOOL isDay) {
    switch (code) {
        case 0:  return isDay ? @"tornado_day" : @"tornado_night";
        case 1:  return isDay ? @"tropicalStorm_day" : @"tropicalStorm_night";
        case 2:  return isDay ? @"hurricane_day" : @"hurricane_night";
        case 3:  return isDay ? @"severeThunderstorm_day" : @"severeThunderstorm_night";
        case 4:  return isDay ? @"thunderstorm_day" : @"thunderstorm_night";
        case 5:  return isDay ? @"mixedRainAndSnow_day" : @"mixedRainAndSnow_night";
        case 6:  return isDay ? @"mixedRainAndSleet_day" : @"mixedRainAndSleet_night";
        case 7:  return isDay ? @"mixedSnowAndSleet_day" : @"mixedSnowAndSleet_night";
        case 8:
        case 9:  return isDay ? @"drizzle_day" : @"drizzle_night";
        case 10: return isDay ? @"rain_day" : @"rain_night";
        case 11: return isDay ? @"showers_day" : @"showers_night";
        case 12: return isDay ? @"rain_day" : @"rain_night";
        case 13: return isDay ? @"flurries_day" : @"flurries_night";
        case 14: return isDay ? @"snowShowers_day" : @"snowShowers_night";
        case 15: return isDay ? @"blowingSnow_day" : @"blowingSnow_night";
        case 16: return isDay ? @"snow_day" : @"snow_night";
        case 17: return isDay ? @"hail_day" : @"hail_night";
        case 18: return isDay ? @"sleet_day" : @"sleet_night";
        case 19: return isDay ? @"dust_day" : @"dust_night";
        case 20: return isDay ? @"fog_day" : @"fog_night";
        case 21: return isDay ? @"haze_day" : @"haze_night";
        case 22: return isDay ? @"smoke_day" : @"smoke_night";
        case 23: return isDay ? @"breezy_day" : @"breezy_night";
        case 24: return isDay ? @"windy_day" : @"windy_night";
        case 25: return isDay ? @"frigid_day" : @"frigid_night";
        case 26: return isDay ? @"cloudy_day" : @"cloudy_night";
        case 27: return @"mostlyCloudy_night";
        case 28: return @"mostlyCloudy_day";
        case 29: return @"partlyCloudy_night";
        case 30: return @"partlyCloudy_day";
        case 31: return @"clear";
        case 32: return @"sunny";
        case 33: return @"mostlyClear";
        case 34: return @"mostlySunny";
        case 35: return isDay ? @"mixedRainfall_day" : @"mixedRainfall_night";
        case 36: return isDay ? @"hot" : @"clear";
        case 37: return isDay ? @"isolatedThunderstorms_day" : @"isolatedThunderstorms_night";
        case 38: return isDay ? @"scatteredThunderstorms_day" : @"scatteredThunderstorms_night";
        case 39: return isDay ? @"scatteredShowers_day" : @"scatteredShowers_night";
        case 40: return isDay ? @"heavyRain_day" : @"heavyRain_night";
        case 41: return isDay ? @"scatteredSnowShowers_day" : @"scatteredSnowShowers_night";
        case 42: return isDay ? @"heavySnow_day" : @"heavySnow_night";
        case 43: return isDay ? @"blizzard_day" : @"blizzard_night";
        case 44: return isDay ? @"sunny" : @"clear";
        case 45: return isDay ? @"scatteredShowers_day" : @"scatteredShowers_night";
        case 46: return isDay ? @"scatteredSnowShowers_day" : @"scatteredSnowShowers_night";
        case 47: return @"isolatedThundershowers";
        default: return isDay ? @"sunny" : @"clear";
    }
}

static NSURL *ASTResolveCAMLURL(NSString *baseName) {
    if (!baseName) return nil;

    NSArray<NSString *> *suffixes = nil;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        suffixes = @[@"@iPad", @"@3x-896h-d33", @"@3x-812h", @"@3x-xx1h", @"@3x-736h", @"@2x-896h-n84", @"@2x-896-n84", @"@2x-667h", @"@2x-568m", @"@3x", @"@2x", @""];
    } else {
        CGFloat scale = [UIScreen mainScreen].scale;
        CGFloat maxDim = MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
        if (scale >= 3.0) {
            if (maxDim >= 896.0) {
                suffixes = @[@"@3x-896h-d33", @"@3x-812h", @"@3x-xx1h", @"@3x-736h", @"@2x-896h-n84", @"@2x-896-n84", @"@2x-667h", @"@2x-568m", @"@iPad", @"@3x", @"@2x", @""];
            } else if (maxDim >= 812.0) {
                suffixes = @[@"@3x-812h", @"@3x-896h-d33", @"@3x-xx1h", @"@3x-736h", @"@2x-896h-n84", @"@2x-896-n84", @"@2x-667h", @"@2x-568m", @"@iPad", @"@3x", @"@2x", @""];
            } else {
                suffixes = @[@"@3x-736h", @"@3x-812h", @"@3x-896h-d33", @"@3x-xx1h", @"@2x-667h", @"@2x-568m", @"@iPad", @"@3x", @"@2x", @""];
            }
        } else {
            if (maxDim >= 812.0) {
                suffixes = @[@"@2x-896h-n84", @"@2x-896-n84", @"@2x-667h", @"@2x-568m", @"@3x-812h", @"@3x-736h", @"@iPad", @"@2x", @""];
            } else if (maxDim >= 667.0) {
                suffixes = @[@"@2x-667h", @"@2x-896h-n84", @"@2x-896-n84", @"@2x-568m", @"@3x-812h", @"@3x-736h", @"@iPad", @"@2x", @""];
            } else {
                suffixes = @[@"@2x-568m", @"@2x-667h", @"@2x-896h-n84", @"@2x-896-n84", @"@3x-812h", @"@3x-736h", @"@iPad", @"@2x", @""];
            }
        }
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundledMicaDir = ROOT_PATH_NS(@"/Library/Application Support/Asteroid/Mica");
    NSArray<NSString *> *baseDirs = @[
        bundledMicaDir,
        @"/System/Library/PrivateFrameworks/WeatherUI.framework/Mica",
        @"/System/Library/PrivateFrameworks/WeatherUI.framework",
        @"/System/Library/PrivateFrameworks/Weather.framework/Mica",
        @"/System/Library/PrivateFrameworks/Weather.framework"
    ];

    for (NSString *dir in baseDirs) {
        for (NSString *suffix in suffixes) {
            NSString *fileName = [NSString stringWithFormat:@"%@%@.caml", baseName, suffix];
            NSString *fullPath = [dir stringByAppendingPathComponent:fileName];
            if ([fm fileExistsAtPath:fullPath]) {
                NSLog(@"[Asteroid] ASTResolveCAMLURL: Resolved %@ -> %@", baseName, fullPath);
                return [NSURL fileURLWithPath:fullPath];
            }
        }
    }

    NSBundle *wuBundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/WeatherUI.framework"];
    if (wuBundle) {
        for (NSString *suffix in suffixes) {
            NSString *resName = [baseName stringByAppendingString:suffix];
            NSURL *url = [wuBundle URLForResource:resName withExtension:@"caml" subdirectory:@"Mica"]
                      ?: [wuBundle URLForResource:resName withExtension:@"caml" subdirectory:nil];
            if (url) return url;
        }
    }
    return nil;
}

static CALayer *ASTLoadCAMLRootLayerFromURL(NSURL *camlURL) {
    if (!camlURL) return nil;
    NSData *data = [NSData dataWithContentsOfURL:camlURL];
    if (data.length == 0) return nil;

    Class parserClass = objc_getClass("CAMLParser");
    if (!parserClass || ![parserClass respondsToSelector:@selector(parser)]) return nil;

    CALayer *rootLayer = nil;
    @try {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        CAMLParser *parser = [parserClass parser];
        [parser setDelegate:[ASTCAMLParserDelegate sharedDelegate]];
        NSURL *baseURL = [[camlURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
        if (baseURL) {
            [parser setBaseURL:baseURL];
        }
        if ([parser respondsToSelector:@selector(parseData:)]) {
            [parser parseData:data];
        } else if ([parser respondsToSelector:@selector(parseBytes:length:)]) {
            [parser parseBytes:(const char *)data.bytes length:data.length];
        }
        id res = [parser result];
        if ([res isKindOfClass:[CALayer class]]) {
            rootLayer = (CALayer *)res;
        }
        [CATransaction commit];
    } @catch (NSException *e) {
        rootLayer = nil;
    }

    if (!rootLayer) {
        dlopen("/System/Library/PrivateFrameworks/WeatherUI.framework/WeatherUI", RTLD_LAZY);
        Class loaderClass = objc_getClass("CAMLLoader");
        if (loaderClass) {
            @try {
                id loader = [[loaderClass alloc] init];
                if ([loader respondsToSelector:@selector(loadCAMLFile:)]) {
                    id res = ((id (*)(id, SEL, id))objc_msgSend)(loader, @selector(loadCAMLFile:), camlURL);
                    if ([res isKindOfClass:[CALayer class]]) {
                        rootLayer = (CALayer *)res;
                    }
                }
            } @catch (NSException *e) {}
        }
    }

    return rootLayer;
}

@implementation ASTWeatherCondition {
    id _stateController;
}

- (instancetype)init {
    if (self = [super init]) {
        _layer = [CALayer layer];
        _playing = YES;
        _alpha = 1.0;
    }
    return self;
}

- (void)setStateController:(id)stateController {
    _stateController = stateController;
}

- (void)pause {
    if (_playing && _layer) {
        CFTimeInterval pausedTime = [_layer convertTime:CACurrentMediaTime() fromLayer:nil];
        _layer.speed = 0.0;
        _layer.timeOffset = pausedTime;
    }
    _playing = NO;
}

- (void)resume {
    if (!_playing && _layer) {
        CFTimeInterval pausedTime = _layer.timeOffset;
        _layer.speed = 1.0;
        _layer.timeOffset = 0.0;
        _layer.beginTime = 0.0;
        CFTimeInterval timeSincePause = [_layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
        _layer.beginTime = timeSincePause;
    }
    _playing = YES;
}

@end

@implementation ASTDynamicWeatherBackground {
    CALayer *_camlRootLayer;
    CGSize _camlNaturalSize;
    CAEmitterLayer *_emitterLayer;
    ASTWeatherCondition *_condition;
}

- (ASTWeatherCondition *)condition {
    return _condition;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = NO;

        _gradientLayer = [CAGradientLayer layer];
        _gradientLayer.frame = self.bounds;
        _gradientLayer.startPoint = CGPointMake(0.5, 0.0);
        _gradientLayer.endPoint = CGPointMake(0.5, 1.0);
        [self.layer addSublayer:_gradientLayer];

        _condition = [[ASTWeatherCondition alloc] init];
        _condition.layer.frame = self.bounds;
        [self.layer addSublayer:_condition.layer];
    }
    return self;
}

- (void)_layoutWeatherLayers {
    CGRect bounds = self.bounds;
    if (bounds.size.width <= 0 || bounds.size.height <= 0) {
        bounds = [UIScreen mainScreen].bounds;
    }
    _gradientLayer.frame = self.bounds;
    _condition.layer.frame = self.bounds;

    if (_camlRootLayer && _camlNaturalSize.width > 0 && _camlNaturalSize.height > 0) {
        CGFloat scaleX = bounds.size.width / _camlNaturalSize.width;
        CGFloat scaleY = bounds.size.height / _camlNaturalSize.height;
        CGFloat scale = MAX(scaleX, scaleY);
        _camlRootLayer.bounds = CGRectMake(0, 0, _camlNaturalSize.width, _camlNaturalSize.height);
        _camlRootLayer.anchorPoint = CGPointMake(0.5, 0.5);
        _camlRootLayer.position = CGPointMake(CGRectGetMidX(bounds), (_camlNaturalSize.height * scale) * 0.5);
        _camlRootLayer.transform = CATransform3DMakeScale(scale, scale, 1.0);
    }

    if (_emitterLayer) {
        _emitterLayer.frame = bounds;
        _emitterLayer.emitterPosition = CGPointMake(bounds.size.width / 2.0, -10.0);
        _emitterLayer.emitterSize = CGSizeMake(bounds.size.width * 1.2, 1.0);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self _layoutWeatherLayers];
    [CATransaction commit];
}

- (void)_stripOpaqueSublayerBackgroundsIfNeeded {
    if (!(_hidesBackground || _condition.hidesConditionBackground) || !_camlRootLayer) {
        return;
    }
    for (CALayer *firstLayer in _camlRootLayer.sublayers) {
        if (firstLayer.backgroundColor) {
            firstLayer.backgroundColor = [UIColor clearColor].CGColor;
        }
        for (CALayer *secLayer in firstLayer.sublayers) {
            if (![secLayer isKindOfClass:[CAEmitterLayer class]] && ![secLayer isKindOfClass:[CATransformLayer class]]) {
                if (secLayer.backgroundColor) {
                    secLayer.backgroundColor = [UIColor clearColor].CGColor;
                }
                if ([secLayer.name containsString:@"Underlying"] || [secLayer.name containsString:@"Gradient"] || [secLayer.name containsString:@"Darken"]) {
                    secLayer.hidden = YES;
                }
            }
            for (CALayer *thrLayer in secLayer.sublayers) {
                if (![thrLayer isKindOfClass:[CAEmitterLayer class]] && ![thrLayer isKindOfClass:[CATransformLayer class]]) {
                    if (thrLayer.backgroundColor) {
                        thrLayer.backgroundColor = [UIColor clearColor].CGColor;
                    }
                }
            }
        }
    }
}

- (void)setHidesBackground:(BOOL)hidesBackground {
    _hidesBackground = hidesBackground;
    _gradientLayer.hidden = hidesBackground;
    [self _stripOpaqueSublayerBackgroundsIfNeeded];
}

- (void)setHidesConditions:(BOOL)hidesConditions {
    _hidesConditions = hidesConditions;
    _condition.layer.hidden = hidesConditions;
}

- (void)setCity:(City *)city {
    _city = city;
    _condition.city = city;
    long long code = city ? (long long)[city conditionCode] : 32;
    BOOL isDay = city ? [city isDay] : YES;
    [self _applyCondition:code isDay:isDay];
}

- (void)setCondition:(long long)conditionCode {
    BOOL isDay = _city ? [_city isDay] : YES;
    [self _applyCondition:conditionCode isDay:isDay];
}

- (void)_applySkyGradientForCondition:(long long)code isDay:(BOOL)effectiveIsDay {
    BOOL appliedOfficialGradient = NO;
    dlopen("/System/Library/PrivateFrameworks/Weather.framework/Weather", RTLD_LAZY);
    Class gradProviderClass = objc_getClass("WAGradientProvider");
    if (gradProviderClass) {
        static id sharedGradProvider = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedGradProvider = [[gradProviderClass alloc] init];
        });
        if ([sharedGradProvider respondsToSelector:@selector(gradientForConditionCode:isDay:)]) {
            @try {
                NSArray *colors = ((id (*)(id, SEL, long long, BOOL))objc_msgSend)(
                    sharedGradProvider, @selector(gradientForConditionCode:isDay:), code, effectiveIsDay);
                if ([colors isKindOfClass:[NSArray class]] && colors.count >= 2) {
                    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
                    for (id c in colors) {
                        if ([c isKindOfClass:[UIColor class]]) {
                            [cgColors addObject:(__bridge id)[(UIColor *)c CGColor]];
                        } else {
                            [cgColors addObject:c];
                        }
                    }
                    if (cgColors.count >= 2) {
                        _gradientLayer.colors = cgColors;
                        if (cgColors.count == 3) {
                            _gradientLayer.locations = @[@0.0, @0.55, @1.0];
                        } else {
                            _gradientLayer.locations = @[@0.0, @1.0];
                        }
                        appliedOfficialGradient = YES;
                    }
                }
            } @catch (NSException *e) {}
        }
    }

    if (!appliedOfficialGradient) {
        UIColor *topColor = nil;
        UIColor *bottomColor = nil;
        switch (code) {
            case 0: case 1: case 2: case 3: case 4: case 37: case 38: case 39: case 45: case 47:
                topColor = [UIColor colorWithRed:0.09 green:0.13 blue:0.18 alpha:1.0];
                bottomColor = [UIColor colorWithRed:0.22 green:0.32 blue:0.42 alpha:1.0];
                break;
            case 5: case 6: case 7: case 8: case 9: case 10: case 11: case 12: case 35: case 40:
                topColor = effectiveIsDay ? [UIColor colorWithRed:0.20 green:0.29 blue:0.38 alpha:1.0]
                                          : [UIColor colorWithRed:0.08 green:0.12 blue:0.18 alpha:1.0];
                bottomColor = effectiveIsDay ? [UIColor colorWithRed:0.35 green:0.48 blue:0.58 alpha:1.0]
                                             : [UIColor colorWithRed:0.16 green:0.24 blue:0.34 alpha:1.0];
                break;
            case 13: case 14: case 15: case 16: case 17: case 18: case 25: case 41: case 42: case 43: case 46:
                topColor = effectiveIsDay ? [UIColor colorWithRed:0.32 green:0.42 blue:0.52 alpha:1.0]
                                          : [UIColor colorWithRed:0.10 green:0.15 blue:0.24 alpha:1.0];
                bottomColor = effectiveIsDay ? [UIColor colorWithRed:0.65 green:0.75 blue:0.82 alpha:1.0]
                                             : [UIColor colorWithRed:0.22 green:0.28 blue:0.40 alpha:1.0];
                break;
            case 19: case 20: case 21: case 22: case 26:
                topColor = effectiveIsDay ? [UIColor colorWithRed:0.30 green:0.39 blue:0.48 alpha:1.0]
                                          : [UIColor colorWithRed:0.11 green:0.15 blue:0.22 alpha:1.0];
                bottomColor = effectiveIsDay ? [UIColor colorWithRed:0.52 green:0.60 blue:0.68 alpha:1.0]
                                             : [UIColor colorWithRed:0.22 green:0.28 blue:0.36 alpha:1.0];
                break;
            default:
                if (effectiveIsDay) {
                    topColor = [UIColor colorWithRed:0.11 green:0.54 blue:0.73 alpha:1.0];
                    bottomColor = [UIColor colorWithRed:0.40 green:0.67 blue:0.80 alpha:1.0];
                } else {
                    topColor = [UIColor colorWithRed:0.00 green:0.02 blue:0.13 alpha:1.0];
                    bottomColor = [UIColor colorWithRed:0.19 green:0.23 blue:0.35 alpha:1.0];
                }
                break;
        }
        _gradientLayer.colors = @[(__bridge id)topColor.CGColor, (__bridge id)bottomColor.CGColor];
        _gradientLayer.locations = @[@0.0, @1.0];
    }
    _gradientLayer.hidden = _hidesBackground;
}

- (void)_applyCondition:(long long)code isDay:(BOOL)isDay {
    _condition.condition = code;

    BOOL effectiveIsDay = isDay;
    if (code == 27 || code == 29 || code == 31 || code == 33) {
        effectiveIsDay = NO;
    } else if (code == 28 || code == 30 || code == 32 || code == 34 || code == 36) {
        effectiveIsDay = YES;
    }

    NSString *baseName = ASTCAMLBaseNameForCondition(code, effectiveIsDay);
    if ([baseName containsString:@"day"] || [baseName containsString:@"night"]) {
        _condition.loadedFileName = baseName;
    } else {
        _condition.loadedFileName = [NSString stringWithFormat:@"%@_%@", baseName, effectiveIsDay ? @"day" : @"night"];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    [self _applySkyGradientForCondition:code isDay:effectiveIsDay];

    [_camlRootLayer removeFromSuperlayer];
    _camlRootLayer = nil;
    [_emitterLayer removeFromSuperlayer];
    _emitterLayer = nil;

    NSURL *camlURL = ASTResolveCAMLURL(baseName);
    CALayer *camlRoot = ASTLoadCAMLRootLayerFromURL(camlURL);

    if (camlRoot) {
        NSLog(@"[Asteroid] Successfully loaded official Apple Mica animation: %@ (%@)", baseName, camlURL.lastPathComponent);
        _camlNaturalSize = camlRoot.bounds.size;
        if (_camlNaturalSize.width <= 0 || _camlNaturalSize.height <= 0) {
            _camlNaturalSize = CGSizeMake(1125.0, 2436.0);
        }
        camlRoot.geometryFlipped = YES;

        Class stateCtrlClass = objc_getClass("CAStateController");
        if (stateCtrlClass) {
            @try {
                CAStateController *stateCtrl = [[stateCtrlClass alloc] initWithLayer:camlRoot];
                if ([stateCtrl respondsToSelector:@selector(setInitialStatesOfLayer:)]) {
                    [stateCtrl setInitialStatesOfLayer:camlRoot];
                }
                [_condition setStateController:stateCtrl];
            } @catch (NSException *e) {}
        }

        _camlRootLayer = camlRoot;
        [_condition.layer addSublayer:_camlRootLayer];
        [self _stripOpaqueSublayerBackgroundsIfNeeded];
        [self _layoutWeatherLayers];
    } else {
        NSLog(@"[Asteroid] ERROR: Failed to load CAML root layer for condition: %@ (code: %lld) at URL: %@", baseName, code, camlURL);
    }

    _condition.layer.hidden = _hidesConditions;
    [CATransaction commit];
}

@end

@implementation ASTWeatherConditionBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = NO;
        _background = [[ASTDynamicWeatherBackground alloc] initWithFrame:self.bounds];
        [self addSubview:_background];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _background.frame = self.bounds;
}

- (void)setHidesConditions:(BOOL)hidesConditions {
    _hidesConditions = hidesConditions;
    _background.hidesConditions = hidesConditions;
}

- (void)prepareToSuspend {
    [_background.condition pause];
}

- (void)prepareToResume {
    [_background.condition resume];
}

@end

Class ASTWeatherConditionBackgroundViewClass(void) {
    Class wuiClass = objc_getClass("WUIWeatherConditionBackgroundView");
    if (wuiClass) {
        return wuiClass;
    }
    return [ASTWeatherConditionBackgroundView class];
}
