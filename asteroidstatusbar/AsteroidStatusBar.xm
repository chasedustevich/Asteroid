#include <AppSupport/CPDistributedMessagingCenter.h>
#import <dlfcn.h>
#import "../source/UIImage+ScaledImage.h"
#import "../source/LWPProvider.h"

#define isSB [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]

@interface _UIStatusBarStringView : UILabel
@property (nonatomic, assign) BOOL isTime;
@property (nonatomic, assign) BOOL isTapped;
@property (nonatomic, copy) NSString *originalText;
@property (nonatomic, assign) BOOL foundBlocks;
@property (nonatomic, retain) UITapGestureRecognizer *tapGesture;
@property (nonatomic) CGRect timeFrame;
- (void)setText:(id)arg1;
- (NSString *)originalText;
- (void)setAlternateText:(NSString *)arg1;
- (void)setShowsAlternateText:(BOOL)arg1;
- (void)generateWeatherData;
- (void)generateWeatherWithTime:(NSString *)currentTime;
- (void)swapTime:(UIGestureRecognizer *)sender;
- (void)resetTime;
- (NSString *)returnDateString;
@end

@class AsteroidServer;
@interface AsteroidServer : NSObject
+ (AsteroidServer *)sharedInstance;
- (NSString *)returnWeatherTempString;
- (NSDictionary *)returnWeatherItems;
- (NSDictionary *)returnWeatherLogo;
- (UIImage *)returnWeatherLogoImage;
@end

static NSDictionary *getWeatherItems() {
    NSMutableDictionary *serverDict = [NSMutableDictionary new];
    if (isSB && %c(AsteroidServer)) {
        UIImage *img = [[%c(AsteroidServer) sharedInstance] returnWeatherLogoImage];
        NSString *temp = [[%c(AsteroidServer) sharedInstance] returnWeatherTempString];
        if (img) serverDict[@"image"] = img;
        if (temp) serverDict[@"temp"] = temp;
    } else {
        NSString *cachedTemp = [prefs stringForKey:@"cachedWeatherTemp"];
        NSData *cachedIconData = [prefs objectForKey:@"cachedWeatherIconData"];
        if (cachedTemp.length > 0) serverDict[@"temp"] = cachedTemp;
        if ([cachedIconData isKindOfClass:[NSData class]]) {
            UIImage *img = [UIImage imageWithData:cachedIconData];
            if (img) serverDict[@"image"] = img;
        }

        void (*rb_apply)(id) = (void (*)(id))dlsym(RTLD_DEFAULT, "rocketbootstrap_distributedmessagingcenter_apply");
        if (!serverDict[@"temp"] && rb_apply) {
            @try {
                CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"com.midnightchips.AsteroidServer"];
                rb_apply(messagingCenter);
                NSDictionary *weatherItem = [messagingCenter sendMessageAndReceiveReplyName:@"weatherItems" userInfo:nil];
                if (weatherItem[@"image"]) serverDict[@"image"] = [UIImage imageWithData:weatherItem[@"image"]];
                if (weatherItem[@"temp"]) serverDict[@"temp"] = weatherItem[@"temp"];
            } @catch (NSException *e) {}
        }
    }

    if (!serverDict[@"image"]) {
        if (@available(iOS 13.0, *)) {
            serverDict[@"image"] = [UIImage systemImageNamed:@"cloud.sun.fill"];
        }
    }
    if (!serverDict[@"temp"]) {
        serverDict[@"temp"] = @"--";
    }
    return serverDict;
}

%hook _UIStatusBarStringView
%property (nonatomic, assign) BOOL isTime;
%property (nonatomic, assign) BOOL isTapped;
%property (nonatomic, assign) BOOL foundBlocks;
%property (nonatomic, assign) CGRect timeFrame;
%property (nonatomic, retain) UITapGestureRecognizer *tapGesture;

- (void)didMoveToWindow {
    %orig;
    if (self.isTime) {
        self.isTapped = NO;
        NSString *dateStr = [self returnDateString];
        if (dateStr.length > 0) {
            [self setText:dateStr];
        }
    }
    if (self.isTime && !self.tapGesture && self.superview.superview) {
        self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(swapTime:)];
        self.tapGesture.numberOfTapsRequired = 1;
        [self.tapGesture setCancelsTouchesInView:NO];
        [self.superview.superview addGestureRecognizer:self.tapGesture];
    }
}

- (void)setText:(id)arg1 {
    if (self.isTime) {
        if ([arg1 isKindOfClass:[NSString class]] && [(NSString *)arg1 length] > 0 && ![(NSString *)arg1 isEqualToString:@"RUN"]) {
            self.originalText = arg1;
        }
        %orig(@"");
        if (self.isTapped) {
            [UIView transitionWithView:self
                              duration:0.15f
                               options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                            animations:^{
                                [self generateWeatherData];
                            } completion:nil];
        } else {
            if ([prefs boolForKey:@"enableGlyphTimeX"]) {
                [self generateWeatherWithTime:arg1];
            } else {
                [UIView transitionWithView:self
                                  duration:0.15f
                                   options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                                animations:^{
                                    %orig(arg1);
                                } completion:nil];
            }
        }
    } else {
        %orig;
    }
}

%new
- (void)generateWeatherData {
    @try {
        NSDictionary *weatherItems = getWeatherItems();
        UIImage *weatherImage = weatherItems[@"image"];
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

        NSString *tempVal = weatherItems[@"temp"] ?: @"--";
        NSDictionary *attribs = @{ NSFontAttributeName: font };
        NSAttributedString *tempString = [[NSAttributedString alloc] initWithString:tempVal attributes:attribs];
        [imageFixText appendAttributedString:tempString];
        [self setAttributedText:imageFixText];
    } @catch (NSException *e) {}
}

%new
- (void)generateWeatherWithTime:(NSString *)currentTime {
    @try {
        NSDictionary *weatherItems = getWeatherItems();
        UIImage *weatherImage = weatherItems[@"image"];
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

        NSString *timeStr = currentTime ?: self.originalText ?: [self returnDateString] ?: @"";
        NSDictionary *attribs = @{ NSFontAttributeName: font };
        NSAttributedString *tempString = [[NSAttributedString alloc] initWithString:timeStr attributes:attribs];
        [imageFixText appendAttributedString:tempString];
        [self setAttributedText:imageFixText];
    } @catch (NSException *e) {}
}

%new
- (void)swapTime:(UIGestureRecognizer *)sender {
    if (!self.superview.superview) return;
    CGPoint location = [sender locationInView:sender.view];
    CGRect newFrame = [self.superview.superview convertRect:self.frame fromView:self.superview];
    if (CGRectContainsPoint(CGRectMake(newFrame.origin.x, 0, newFrame.size.width, newFrame.size.height + newFrame.origin.y), location)) {
        if (!self.isTapped) {
            self.isTapped = YES;
            [self setText:@"RUN"];
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetTime) object:nil];
            [self performSelector:@selector(resetTime) withObject:nil afterDelay:10];
        } else {
            [self resetTime];
        }
    }
}

%new
- (void)resetTime {
    self.isTapped = NO;
    [self setText:[self returnDateString]];
}

%new
- (NSString *)returnDateString {
    if (self.originalText.length > 0 && ![self.originalText isEqualToString:@"RUN"]) {
        return self.originalText;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    NSString *timeString = [formatter stringFromDate:[NSDate date]] ?: @"";
    timeString = [timeString stringByTrimmingCharactersInSet:[NSCharacterSet letterCharacterSet]];
    timeString = [timeString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return timeString;
}
%end

@interface _UIStatusBarTimeItem
@property (copy) _UIStatusBarStringView *shortTimeView;
@property (copy) _UIStatusBarStringView *pillTimeView;
@end

%hook _UIStatusBarTimeItem
- (_UIStatusBarStringView *)shortTimeView {
    _UIStatusBarStringView *orig = %orig;
    if (orig) {
        orig.isTime = YES;
        orig.timeFrame = orig.frame;
    }
    return orig;
}
%end

%ctor {
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    BOOL isAppOrSB = isSB || [bundlePath hasSuffix:@".app"];
    if (isAppOrSB && [prefs boolForKey:@"enableTimeStatusX"] && [prefs boolForKey:@"kLWPEnabled"]) {
        %init();
    }
}
