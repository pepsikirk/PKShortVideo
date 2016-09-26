//
//  PKShortVideoItem2.m
//  PKShortVideo
//
//  Created by TYM01 on 16/9/26.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKShortVideoItem2.h"
#import "PKPlayerView.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
#import "UIImage+JSQMessages.h"

static CGFloat const PKShortVideoMaxLength = 220;

@interface PKShortVideoItem2 ()

@property (nonatomic, strong) PKPlayerView *playerView;

@end

@implementation PKShortVideoItem2

- (instancetype)initWithVideoPath:(NSString *)videoPath previewImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _image = image;
        _videoPath = videoPath;
    }
    return self;
}

//开始播放小视频
- (void)play {
    [self.playerView play];
}
//结束播放视频
- (void)pause {
    [self.playerView stop];
}

#pragma mark - JSQMessageMediaData protocol

//JSQ协议方法
- (UIView *)mediaView {
    if (!self.videoPath) {
        return nil;
    }
    
    if (!self.playerView) {
        //当前尺寸
        CGSize size = [self mediaViewDisplaySize];
        //实例化播放view
        self.playerView = [[PKPlayerView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) videoPath:self.videoPath previewImage:self.image];
        [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:self.playerView isOutgoing:self.appliesMediaViewMaskAsOutgoing];
    }
    
    return self.playerView;
}

- (CGSize)mediaViewDisplaySize {
    CGFloat height = self.image.size.height * self.image.scale;
    CGFloat width = self.image.size.width * self.image.scale;
    
    CGSize size;
    if (height <= PKShortVideoMaxLength && width <= PKShortVideoMaxLength) {
        size = CGSizeMake(width, height);
    } else {
        if (height > width) {
            size = CGSizeMake(PKShortVideoMaxLength * (width/height), PKShortVideoMaxLength);
        } else {
            size = CGSizeMake(PKShortVideoMaxLength, PKShortVideoMaxLength * (height/width));
        }
    }
    return size;
}

- (NSUInteger)mediaHash {
    return self.hash;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (![super isEqual:object]) {
        return NO;
    }
    
    PKShortVideoItem2 *videoItem = (PKShortVideoItem2 *)object;
    return [self.videoPath isEqual:videoItem.videoPath];
}

- (NSUInteger)hash {
    return super.hash ^ self.videoPath.hash ^ self.image.hash;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _image = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(image))];
        _videoPath = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(videoPath))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.image forKey:NSStringFromSelector(@selector(image))];
    [aCoder encodeObject:self.videoPath forKey:NSStringFromSelector(@selector(videoPath))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    PKShortVideoItem2 *copy = [[[self class] allocWithZone:zone] initWithVideoPath:self.videoPath previewImage:self.image];
    copy.appliesMediaViewMaskAsOutgoing = self.appliesMediaViewMaskAsOutgoing;
    return copy;
}


@end
