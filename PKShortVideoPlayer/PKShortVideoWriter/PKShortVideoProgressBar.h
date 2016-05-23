//
//  PKShortVideoProgressBar.h
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/15.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PKShortVideoProgressBar : UIView

- (instancetype)initWithFrame:(CGRect)frame themeColor:(UIColor *)themeColor duration:(NSTimeInterval)duration;
- (void)play;
- (void)stop;
- (void)restore;

@end

NS_ASSUME_NONNULL_END
