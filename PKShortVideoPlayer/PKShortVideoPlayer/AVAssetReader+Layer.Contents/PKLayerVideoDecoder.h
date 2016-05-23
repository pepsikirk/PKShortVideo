//
//  PKVideoDecoder.h
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/7.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@class PKLayerVideoDecoder;

@protocol PKVideoDecoderDelegate <NSObject>

@required
- (void)videoDecoderDidDecodeFrame:(PKLayerVideoDecoder *)decoder pixelBuffer:(CVImageBufferRef)buffer;

@optional
- (void)videoDecoderDidFinishDecoding:(PKLayerVideoDecoder *)decoder;

@end

@interface PKLayerVideoDecoder : NSObject

@property (nonatomic, assign, readonly) BOOL isRunning, isFinished;
@property (nonatomic, assign) BOOL loop;

@property (nonatomic, weak) id<PKVideoDecoderDelegate> delegate;



- (instancetype)initWithVideoPath:(NSString *)videoPath size:(CGSize)size;

- (void)start;

- (void)pause;

- (void)stop;

@end
