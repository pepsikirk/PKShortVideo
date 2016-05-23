//
//  PKChatMessagePlayerView.m
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/5.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKLayerContentsPlayerView.h"
@import AVFoundation;
#import "PKLayerVideoDecoder.h"

@interface PKLayerContentsPlayerView () <PKVideoDecoderDelegate>

@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, strong) UIImage *previewImage;

@property (nonatomic, strong) PKLayerVideoDecoder *videoDecoder;

@end

@implementation PKLayerContentsPlayerView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame videoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage {
    NSParameterAssert(videoPath != nil);
    NSParameterAssert(previewImage != nil);
    
    self = [super initWithFrame:frame];
    if (self) {
        _videoPath = videoPath;
        _previewImage = previewImage;
        
        _videoDecoder = [[PKLayerVideoDecoder alloc] initWithVideoPath:videoPath size:self.bounds.size];
        _videoDecoder.delegate = self;
        _videoDecoder.loop = YES;
        [_videoDecoder start];
    }
    return self;
}

- (void)stop {
    [self.videoDecoder stop];
}

#pragma mark - PKVideoDecoderDelegate

- (void)videoDecoderDidDecodeFrame:(PKLayerVideoDecoder *)decoder pixelBuffer:(CVImageBufferRef)buffer {
    CGImageRef image = [PKLayerContentsPlayerView imageFromSampleBufferRef:buffer];
    
    if (!image) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.layer.contents = (__bridge id)(image);
        CGImageRelease(image);
    });
}

-(void)videoDecoderDidFinishDecoding:(PKLayerVideoDecoder *)decoder {
    
}

#pragma mark - Utility

+ (CGImageRef)imageFromSampleBufferRef:(CVImageBufferRef)imageBuffer {
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVBufferRelease(imageBuffer);
    
    return quartzImage;
}


@end
