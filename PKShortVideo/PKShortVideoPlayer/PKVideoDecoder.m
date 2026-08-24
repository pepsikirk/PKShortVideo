//
//  PKVideoDecoder.m
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/11.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKVideoDecoder.h"
#import "GLProgram.h"
#import "GPUImageContext.h"
#import "PKColorConversion.h"

@interface PKVideoDecoder () {
    GPUImageFramebuffer *outputFramebuffer;
    GLProgram *yuvConversionProgram;
    
    CMTime previousFrameTime, processingFrameTime;
    CFAbsoluteTime previousActualFrameTime;
    
    GLuint luminanceTexture, chrominanceTexture;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    
    const GLfloat *_preferredConversion;
    
    int imageBufferWidth, imageBufferHeight;
}

@property (nonatomic, assign) CGSize size;

@property (nonatomic, strong, readwrite) AVAssetReader *reader;

@property (atomic, assign) BOOL foreground;

@end

@implementation PKVideoDecoder



#pragma mark - Initialization

- (instancetype)initWithVideoPath:(NSString *)videoPath size:(CGSize)size {
    self = [super init];
    if (self) {
        _videoPath = videoPath;
        _size = size;
        _asset = nil;
        _keepLooping = YES;
        
        [self yuvConversionSetup];
    }
    return self;
}

- (void)dealloc {
    [_reader cancelReading];
}

- (void)yuvConversionSetup {
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        
        _preferredConversion = kColorConversion709;
        yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];
        
        if (!yuvConversionProgram.initialized) {
            [yuvConversionProgram addAttribute:@"position"];
            [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
            
            if (![yuvConversionProgram link]) {
                NSString *progLog = [yuvConversionProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [yuvConversionProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                yuvConversionProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
        yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
        yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
        yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
        yuvConversionMatrixUniform = [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
        
        [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
        
        glEnableVertexAttribArray(yuvConversionPositionAttribute);
        glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
    });
}

- (AVAssetReader*)createAssetReader {
    if (!self.asset) {
        NSLog(@"视频资源为空，不能创建解码器");
        return nil;
    }

    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
    if (!assetReader) {
        NSLog(@"创建 AVAssetReader 失败: %@", error.localizedDescription);
        return nil;
    }

    AVAssetTrack *assetTrack = [self.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!assetTrack) {
        NSLog(@"视频资源没有视频轨道");
        return nil;
    }
    
    CGSize naturalSize = assetTrack.naturalSize;
    CGSize outputSize = self.size;
    if (outputSize.width <= 0 || outputSize.height <= 0 ||
        outputSize.width > naturalSize.width || outputSize.height > naturalSize.height) {
        outputSize = naturalSize;
    }
    
    NSDictionary *outputSettings = @{
                                     (id)kCVPixelBufferWidthKey:@(outputSize.width),
                                     (id)kCVPixelBufferHeightKey:@(outputSize.height),
                                     (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
                                     };
    
    AVAssetReaderTrackOutput *readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetTrack outputSettings:outputSettings];
    readerVideoTrackOutput.alwaysCopiesSampleData = NO;
    if (![assetReader canAddOutput:readerVideoTrackOutput]) {
        NSLog(@"不能向 AVAssetReader 添加视频输出");
        return nil;
    }
    [assetReader addOutput:readerVideoTrackOutput];
    
    self.reader = assetReader;
    
    return assetReader;
}

- (void)processAsset {
    AVAssetReader *reader = [self createAssetReader];
    if (!reader) {
        if (self.foreground) {
            [self endProcessing];
        }
        return;
    }
    
    AVAssetReaderOutput *readerVideoTrackOutput = nil;
    
    for( AVAssetReaderOutput *output in reader.outputs ) {
        if( [output.mediaType isEqualToString:AVMediaTypeVideo] ) {
            readerVideoTrackOutput = output;
        }
    }
    
    if (reader.status == AVAssetReaderStatusUnknown && ![reader startReading] && self.foreground) {
        NSLog(@"Error reading from file at Path: %@", self.videoPath);
        [self endProcessing];
        return;
    }
    
    __weak typeof(self)weakSelf = self;
    
    while (reader.status == AVAssetReaderStatusReading && self.foreground) {
        @autoreleasepool {
            [weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput reader:reader];
        }
    }
    
    [reader cancelReading];

    if (reader.status == AVAssetReaderStatusCompleted && self.foreground) {
        if (self.keepLooping) {
            self.reader = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startProcessing];
            });
        } else {
            [weakSelf endProcessing];
        }
    }
}



#pragma mark - Public

- (void)startProcessing {
    self.foreground = YES;
    
    previousFrameTime = kCMTimeZero;
    previousActualFrameTime = CFAbsoluteTimeGetCurrent();
    
    if (self.asset) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self processAsset];
        });
        return;
    }
    
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:self.videoPath] options:inputOptions];
    
    __weak typeof(self)weakSelf = self;;
    
    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler: ^{
        
        if (!weakSelf) {
            return;
        }
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        
        NSError *error = nil;
        AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"tracks" error:&error];
        if (tracksStatus != AVKeyValueStatusLoaded) {
            return;
        }
        strongSelf.asset = inputAsset;
        [strongSelf processAsset];
    }];
}

- (void)endProcessing {
    if (self.delegate && [self.delegate respondsToSelector:@selector(didCompletePlayingMovie)]) {
        [self.delegate didCompletePlayingMovie];
    }
}

- (void)cancelProcessing {
    self.foreground = NO;
    
    [self endProcessing];
}

- (void)convertYUVToRGBOutput {
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(imageBufferWidth, imageBufferHeight) onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(yuvConversionLuminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(yuvConversionChrominanceTextureUniform, 5);
    
    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
    
    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}



#pragma mark - Pravite

- (BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput reader:(AVAssetReader*)reader {
    if (readerVideoTrackOutput && reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sampleBufferRef = [readerVideoTrackOutput copyNextSampleBuffer];
        if (sampleBufferRef) {
            // Do this outside of the video processing queue to not slow that down while waiting
            CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);
            CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime);
            CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
            
            CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
            CGFloat actualTimeDifference = currentActualTime - previousActualFrameTime;
            
            if (frameTimeDifference > actualTimeDifference) {
                usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
            }
            
            previousFrameTime = currentSampleTime;
            previousActualFrameTime = CFAbsoluteTimeGetCurrent();
            
            __weak typeof(self)weakSelf = self;
            runSynchronouslyOnVideoProcessingQueue(^{
                [weakSelf processMovieFrame:sampleBufferRef];
                CMSampleBufferInvalidate(sampleBufferRef);
                CFRelease(sampleBufferRef);
            });
            
            return YES;
        }
        else {
            if (!self.keepLooping) {
                [self endProcessing];
            }
        }
    }
    return NO;
}

- (void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer {
    if (!movieSampleBuffer) {
        return;
    }
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(movieSampleBuffer);
    CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(movieSampleBuffer);
    if (!movieFrame) {
        return;
    }
    
    processingFrameTime = currentSampleTime;
    [self processMovieFrame:movieFrame withSampleTime:currentSampleTime];
}

- (void)processMovieFrame:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime {
    if (!movieFrame) {
        return;
    }
    int bufferHeight = (int) CVPixelBufferGetHeight(movieFrame);
    int bufferWidth = (int) CVPixelBufferGetWidth(movieFrame);
    
    CFTypeRef colorAttachments = CVBufferGetAttachment(movieFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL) {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            _preferredConversion = kColorConversion601FullRange;
        }
        else {
            _preferredConversion = kColorConversion709;
        }
    }
    else {
        _preferredConversion = kColorConversion601FullRange;
    }
    
    [GPUImageContext useImageProcessingContext];
    
    CVOpenGLESTextureRef luminanceTextureRef = NULL;
    CVOpenGLESTextureRef chrominanceTextureRef = NULL;
    
    if (CVPixelBufferGetPlaneCount(movieFrame) > 0) {// Check for YUV planar inputs to do RGB conversion
        if ( (imageBufferWidth != bufferWidth) || (imageBufferHeight != bufferHeight) ) {
            imageBufferWidth = bufferWidth;
            imageBufferHeight = bufferHeight;
        }
        
        CVReturn err;
        // Y-plane
        glActiveTexture(GL_TEXTURE4);
        if ([GPUImageContext deviceSupportsRedTextures]) {
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
        }
        else {
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
        }
        if (err != kCVReturnSuccess || !luminanceTextureRef) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            if (luminanceTextureRef) {
                CFRelease(luminanceTextureRef);
            }
            return;
        }
        
        luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
        
        glBindTexture(GL_TEXTURE_2D, luminanceTexture);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // UV-plane
        glActiveTexture(GL_TEXTURE5);
        if ([GPUImageContext deviceSupportsRedTextures]) {
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
        }
        else {
            err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], movieFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
        }
        if (err != kCVReturnSuccess || !chrominanceTextureRef) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            CFRelease(luminanceTextureRef);
            if (chrominanceTextureRef) {
                CFRelease(chrominanceTextureRef);
            }
            return;
        }
        
        chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
        
        glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        [self convertYUVToRGBOutput];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(didDecodeInputFramebuffer:inputSize:frameTime:)]) {
            [self.delegate didDecodeInputFramebuffer:outputFramebuffer inputSize:CGSizeMake(bufferWidth, bufferHeight) frameTime:currentSampleTime];
        }
        [outputFramebuffer unlock];
        
        CFRelease(luminanceTextureRef);
        CFRelease(chrominanceTextureRef);
    }
}



#pragma mark - Getter

- (CGFloat)progress {
    if ( AVAssetReaderStatusReading == self.reader.status ) {
        float current = processingFrameTime.value * 1.0f / processingFrameTime.timescale;
        float duration = self.asset.duration.value * 1.0f / self.asset.duration.timescale;
        return current / duration;
    }
    else if ( AVAssetReaderStatusCompleted == self.reader.status ) {
        return 1.f;
    }
    else {
        return 0.f;
    }
}

- (AVAssetReader*)assetReader {
    return self.reader;
}


@end
