//
//  PKShortVideoItem.h
//  PKShortVideo
//
//  Created by pepsikirk on 16/1/3.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "JSQMediaItem.h"

static CGFloat const PKShortVideoMaxLength = 220;


@interface PKShortVideoItem : JSQMediaItem

@property (nonatomic, strong) NSURL *fileURL;

@property (strong, nonatomic) UIImage *image;

- (void)play ;

- (void)pause;

@end
