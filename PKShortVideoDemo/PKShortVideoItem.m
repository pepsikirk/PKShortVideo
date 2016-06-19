//
//  PKShortVideoItem.m
//  PKShortVideo
//
//  Created by pepsikirk on 16/1/3.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKShortVideoItem.h"
#import "PKChatMessagePlayerView.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"
#import "UIImage+JSQMessages.h"

@interface PKShortVideoItem ()

@property (nonatomic, strong) PKChatMessagePlayerView *playerView;

@end

@implementation PKShortVideoItem

- (instancetype)initWithVideoPath:(NSString *)videoPath previewImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _image = image;
        _videoPath = videoPath;
    }
    return self;
}

- (void)play {
    self.playerView;
}

- (void)pause {
    self.playerView;
}

#pragma mark - JSQMessageMediaData protocol

- (UIView *)mediaView {
    if (!self.videoPath) {
        return nil;
    }
    
    if (!self.playerView) {
        CGSize size = [self mediaViewDisplaySize];
        self.playerView = [[PKChatMessagePlayerView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) videoPath:self.videoPath previewImage:self.image];
        [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:self.playerView isOutgoing:self.appliesMediaViewMaskAsOutgoing];
    }
    return self.playerView;
}

- (NSUInteger)mediaHash {
    return self.hash;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (![super isEqual:object]) {
        return NO;
    }
    
    PKShortVideoItem *videoItem = (PKShortVideoItem *)object;
    return [self.videoPath isEqual:videoItem.videoPath];
}

- (NSUInteger)hash {
    return super.hash ^ self.videoPath.hash ^ self.image.hash;
}

#pragma mark - Extention

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


@end
