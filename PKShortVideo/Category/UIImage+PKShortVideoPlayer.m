//
//  UIImage+PKShortVideoPlayer.m
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/4.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "UIImage+PKShortVideoPlayer.h"
@import AVFoundation;

@implementation UIImage (PKShortVideoPlayer)

+ (UIImage *)pk_previewImageWithVideoURL:(NSURL *)videoURL {
    if (!videoURL) {
        return nil;
    }

    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    if (!asset) {
        return nil;
    }
    
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;

    CGImageRef img = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:nil];
    UIImage *image = img ? [UIImage imageWithCGImage:img] : nil;
    
    if (img) {
        CGImageRelease(img);
    }
    return image;
}

@end
