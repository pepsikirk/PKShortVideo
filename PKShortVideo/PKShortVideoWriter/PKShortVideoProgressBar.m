//
//  PKShortVideoProgressBar.m
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/15.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKShortVideoProgressBar.h"

static NSInteger const PKProgressItemWidth = 5;

@interface PKShortVideoProgressBar ()

@property (nonatomic, assign) NSTimeInterval duration;

@property (nonatomic, strong) UIColor *themeColor;

@property (strong, nonatomic) UIView *progressItem;
@property (strong, nonatomic) UIView *progressingView;
@property (nonatomic, strong) UIView *coverView;

@property (nonatomic, assign) CFTimeInterval beginTime;
@property (nonatomic, assign) CGFloat lastLayoutWidth;
@property (nonatomic, assign) BOOL isPlaying;

@end

@implementation PKShortVideoProgressBar

#pragma mark - Public

- (instancetype)initWithFrame:(CGRect)frame themeColor:(UIColor *)themeColor duration:(NSTimeInterval)duration {
    self = [super initWithFrame:frame];
    if (self) {
        _themeColor = themeColor;
        _duration = duration;
        
        _coverView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _coverView.backgroundColor = [UIColor blackColor];
        _coverView.alpha = 0.4f;
        [self addSubview:_coverView];
        
        _progressItem = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PKProgressItemWidth, frame.size.height)];
        _progressItem.backgroundColor = [UIColor whiteColor];
        [self addSubview:_progressItem];
        
        _progressingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, frame.size.height)];
        _progressingView.backgroundColor = themeColor;
        [self addSubview:_progressingView];
        _lastLayoutWidth = frame.size.width;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat progress = 0;
    if (self.lastLayoutWidth > 0) {
        CALayer *presentationLayer = self.progressItem.layer.presentationLayer;
        CGRect currentFrame = presentationLayer ? presentationLayer.frame : self.progressItem.frame;
        progress = MIN(MAX((CGRectGetMinX(currentFrame) + PKProgressItemWidth) / self.lastLayoutWidth, 0), 1);
    }

    self.coverView.frame = self.bounds;
    [self.progressItem.layer removeAllAnimations];
    [self.progressingView.layer removeAllAnimations];
    CGFloat progressWidth = MAX(0, width * progress - PKProgressItemWidth);
    self.progressItem.frame = CGRectMake(progressWidth, 0, PKProgressItemWidth, height);
    self.progressingView.frame = CGRectMake(0, 0, progressWidth, height);
    self.lastLayoutWidth = width;

    if (self.isPlaying && self.duration > 0 && progress < 1) {
        self.beginTime = CACurrentMediaTime() - progress * self.duration;
        NSTimeInterval remainingDuration = (1 - progress) * self.duration;
        [UIView animateWithDuration:remainingDuration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.progressItem.frame = CGRectMake(width - PKProgressItemWidth, 0, PKProgressItemWidth, height);
            self.progressingView.frame = CGRectMake(0, 0, width - PKProgressItemWidth, height);
        } completion:NULL];
    } else if (progress >= 1) {
        self.isPlaying = NO;
    }
}

- (void)play {
    self.isPlaying = YES;
    self.beginTime = CACurrentMediaTime();
    [UIView animateWithDuration:self.duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressItem.frame = CGRectMake(self.bounds.size.width - PKProgressItemWidth, 0, PKProgressItemWidth, self.bounds.size.height);
        self.progressingView.frame = CGRectMake(0, 0, self.bounds.size.width - PKProgressItemWidth, self.bounds.size.height);
    } completion:NULL];
}

- (void)stop {
    [self.progressItem.layer removeAllAnimations];
    [self.progressingView.layer removeAllAnimations];

    self.isPlaying = NO;
    CGFloat temp = self.duration > 0 ? (CACurrentMediaTime() - self.beginTime) / self.duration : 0;
    temp = MIN(MAX(temp, 0), 1);
    CGFloat progress = temp + 0.018 * (1 - temp);
    self.progressItem.frame = CGRectMake(self.bounds.size.width*(progress) - PKProgressItemWidth, 0, PKProgressItemWidth, self.bounds.size.height);
    self.progressingView.frame = CGRectMake(0, 0, self.bounds.size.width*(progress) - PKProgressItemWidth, self.bounds.size.height);
}

- (void)restore {
    [self.progressItem.layer removeAllAnimations];
    [self.progressingView.layer removeAllAnimations];

    self.isPlaying = NO;
    self.beginTime = 0;
    self.progressItem.frame = CGRectMake(0, 0, PKProgressItemWidth, self.bounds.size.height);
    self.progressingView.frame = CGRectMake(0, 0, 0, self.bounds.size.height);
}


@end
