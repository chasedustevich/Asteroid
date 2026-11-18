#import "ASTComponentView.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface SBIconView : UIView
+ (id)_jitterXTranslationAnimation;
+ (id)_jitterYTranslationAnimation;
+ (id)_jitterRotationAnimation;
@end

@implementation ASTComponentView
@synthesize editing;

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.frame = frame;
        self.layer.cornerRadius = 13;
    }
    return self;
}

- (void)setEditing:(BOOL)edit {
    editing = edit;
    [self handleEditChange];
}

- (void)handleEditChange {
    if (self.isEditing) {
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{ self.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.3]; }
                         completion:^(BOOL finished) {
                             [self addJitterAnimations];
                         }];
    } else {
        [UIView animateWithDuration:0.2
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{ self.backgroundColor = [UIColor clearColor]; }
                         completion:^(BOOL finished) {
                             [self removeJitterAnimations];
                         }];
    }
}

- (void)addJitterAnimations {
    CABasicAnimation *jitterX = [self _jitterXTranslationAnimation];
    CABasicAnimation *jitterY = [self _jitterYTranslationAnimation];
    CABasicAnimation *jitterRotation = [self _jitterRotationAnimation];

    if (jitterX) [self.layer addAnimation:jitterX forKey:@"astAnimateJitterX"];
    if (jitterY) [self.layer addAnimation:jitterY forKey:@"astAnimateJitterY"];
    if (jitterRotation) [self.layer addAnimation:jitterRotation forKey:@"astAnimateJitterRotation"];
}

- (void)removeJitterAnimations {
    [self.layer removeAllAnimations];
}

- (CABasicAnimation *)_jitterXTranslationAnimation {
    Class cls = objc_getClass("SBIconView");
    if ([cls respondsToSelector:@selector(_jitterXTranslationAnimation)]) {
        return [cls _jitterXTranslationAnimation];
    }
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.duration = 0.13;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.fromValue = @(-1.0);
    anim.toValue = @(1.0);
    return anim;
}

- (CABasicAnimation *)_jitterYTranslationAnimation {
    Class cls = objc_getClass("SBIconView");
    if ([cls respondsToSelector:@selector(_jitterYTranslationAnimation)]) {
        return [cls _jitterYTranslationAnimation];
    }
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    anim.duration = 0.14;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.fromValue = @(-1.0);
    anim.toValue = @(1.0);
    return anim;
}

- (CABasicAnimation *)_jitterRotationAnimation {
    Class cls = objc_getClass("SBIconView");
    if ([cls respondsToSelector:@selector(_jitterRotationAnimation)]) {
        return [cls _jitterRotationAnimation];
    }
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    anim.duration = 0.12;
    anim.autoreverses = YES;
    anim.repeatCount = HUGE_VALF;
    anim.fromValue = @(-0.025);
    anim.toValue = @(0.025);
    return anim;
}
@end
