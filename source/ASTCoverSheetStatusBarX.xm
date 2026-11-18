#import "UIImage+ScaledImage.h"
#import "AWeatherModel.h"

@interface _UIStatusBarItem : NSObject
@end

@interface _UIStatusBarCellularItem : _UIStatusBarItem
@end

@interface _UIStatusBarStringView : UILabel
@property (nonatomic, copy) NSString *originalText;
@property (nonatomic, assign) BOOL isServiceView;
- (void)generateWeatherView;
@end

@interface SBStatusBarStateAggregator : NSObject
+ (id)sharedInstance;
- (void)_updateServiceItem;
@end

%hook _UIStatusBarStringView
%property (nonatomic, assign) BOOL isServiceView;
- (void)setText:(id)arg1 {
    if (self.isServiceView) {
        %orig(@"");
        [self generateWeatherView];
    } else {
        %orig;
    }
}
%new
- (void)generateWeatherView {
    @try {
        AWeatherModel *weatherModel = [%c(AWeatherModel) sharedInstance];
        UIImage *weatherImage = [weatherModel glyphWithOption:ConditionOptionDefault];
        if (!weatherImage || weatherImage.size.height <= 0 || weatherImage.size.width <= 0) return;

        UIFont *font = self.font ?: [UIFont systemFontOfSize:12];
        double aspect = weatherImage.size.width / weatherImage.size.height;
        CGFloat lineHeight = font.lineHeight > 0 ? font.lineHeight : 14.0;
        weatherImage = [weatherImage scaleImageToSize:CGSizeMake(lineHeight * aspect, lineHeight)];
        if (!weatherImage) return;

        NSTextAttachment *weatherAttach = [[NSTextAttachment alloc] init];
        [weatherAttach setBounds:CGRectMake(0, roundf(font.capHeight - weatherImage.size.height) / 2.f, weatherImage.size.width, weatherImage.size.height)];
        weatherImage = [weatherImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        weatherAttach.image = weatherImage;

        NSMutableAttributedString *imageFixText = [[NSMutableAttributedString alloc] initWithString:@" "];
        NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:weatherAttach];
        if (attachmentString) {
            [imageFixText appendAttributedString:attachmentString];
        }
        [imageFixText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:0] range:NSMakeRange(0, imageFixText.length)];

        NSString *tempStr = [weatherModel localeTemperature] ?: @"--";
        NSDictionary *attribs = @{ NSFontAttributeName: font };
        NSAttributedString *tempString = [[NSAttributedString alloc] initWithString:tempStr attributes:attribs];
        [imageFixText appendAttributedString:tempString];
        [self setAttributedText:imageFixText];
    } @catch (NSException *e) {}
}
%end

%hook _UIStatusBarCellularItem
- (_UIStatusBarStringView *)serviceNameView {
    _UIStatusBarStringView *orig = %orig;
    if (orig) {
        orig.isServiceView = YES;
    }
    return orig;
}
%end

%ctor {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"] &&
        [prefs boolForKey:@"enableCoverStatusX"] && [prefs boolForKey:@"kLWPEnabled"]) {
        %init();
    }
}
