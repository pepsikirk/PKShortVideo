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
    }
    return self;
}

- (void)play {
    [UIView animateWithDuration:self.duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressItem.frame = CGRectMake(self.bounds.size.width - PKProgressItemWidth, 0, PKProgressItemWidth, self.bounds.size.height);
        self.progressingView.frame = CGRectMake(0, 0, self.bounds.size.width - PKProgressItemWidth, self.bounds.size.height);
        self.beginTime = CACurrentMediaTime();
    } completion:NULL];
}

- (void)stop {
    [self.progressItem.layer removeAllAnimations];
    [self.progressingView.layer removeAllAnimations];
    
    CGFloat temp = (CACurrentMediaTime() - self.beginTime)/self.duration;
    CGFloat progress = temp + 0.018*(1 - temp);
    self.progressItem.frame = CGRectMake(self.bounds.size.width*(progress) - PKProgressItemWidth, 0, PKProgressItemWidth, self.bounds.size.height);
    self.progressingView.frame = CGRectMake(0, 0, self.bounds.size.width*(progress) - PKProgressItemWidth, self.bounds.size.height);
}

- (void)restore {
    [self.progressItem.layer removeAllAnimations];
    [self.progressingView.layer removeAllAnimations];
    
    self.progressItem.frame = CGRectMake(0, 0, PKProgressItemWidth, self.bounds.size.height);
    self.progressingView.frame = CGRectMake(0, 0, 0, self.bounds.size.height);
}


@end
