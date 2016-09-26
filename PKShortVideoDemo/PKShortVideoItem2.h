//
//  PKShortVideoItem2.h
//  PKShortVideo
//
//  Created by TYM01 on 16/9/26.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "JSQMediaItem.h"

@interface PKShortVideoItem2 : JSQMediaItem

@property (nonatomic, strong) NSString *videoPath;
@property (strong, nonatomic) UIImage *image;

- (instancetype)initWithVideoPath:(NSString *)videoPath previewImage:(UIImage *)image;

- (void)play;
- (void)pause;

@end
