//
//  PKVideoDecoder.h
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/11.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class GPUImageFramebuffer;

NS_ASSUME_NONNULL_BEGIN

@protocol PKVideoDecoderDelegate <NSObject>

- (void)didCompletePlayingMovie;

- (void)didDecodeInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer inputSize:(CGSize)newSize frameTime:(CMTime)frameTime;

@end

@interface PKVideoDecoder : NSObject

@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, strong, readonly) AVAssetReader *assetReader;
@property (nonatomic, assign, readonly) CGFloat progress;

@property (nonatomic, assign) BOOL keepLooping;

@property (nonatomic, weak) id <PKVideoDecoderDelegate>delegate;

- (instancetype)initWithVideoPath:(NSString *)videoPath size:(CGSize)size;

- (void)startProcessing;
- (void)endProcessing;
- (void)cancelProcessing;

@end

NS_ASSUME_NONNULL_END

