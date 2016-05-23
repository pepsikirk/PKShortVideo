//
//  PKChatMessagePlayerView.h
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/5.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PKLayerContentsPlayerView : UIView

- (instancetype)initWithFrame:(CGRect)frame videoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
