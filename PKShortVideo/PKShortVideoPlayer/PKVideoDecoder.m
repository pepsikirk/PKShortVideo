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
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
    AVAssetTrack *assetTrack = [[self.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    CGSize outputSize = CGSizeZero;
    if (self.size.width > assetTrack.naturalSize.width) {
        outputSize = assetTrack.naturalSize;
    } else {
        outputSize= self.size;
    }
    
    NSDictionary *outputSettings = @{
                                     (id)kCVPixelBufferWidthKey:@(outputSize.width),
                                     (id)kCVPixelBufferHeightKey:@(outputSize.height),
                                     };
    
    AVAssetReaderTrackOutput *readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetTrack outputSettings:outputSettings];
    readerVideoTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:readerVideoTrackOutput];
    
    self.reader = assetReader;
    
    return assetReader;
}

- (void)processAsset {
    AVAssetReader *reader = [self createAssetReader];
    
    AVAssetReaderOutput *readerVideoTrackOutput = nil;
    
    for( AVAssetReaderOutput *output in reader.outputs ) {
        if( [output.mediaType isEqualToString:AVMediaTypeVideo] ) {
            readerVideoTrackOutput = output;
        }
    }
    
    if (reader.status == AVAssetReaderStatusUnknown && [reader startReading] == NO && self.foreground) {
        NSLog(@"Error reading from file at Path: %@", self.videoPath);
        return;
    }
    
    __weak typeof(self)weakSelf = self;
    
    while (reader.status == AVAssetReaderStatusReading && self.foreground) {
        [weakSelf readNextVideoFrameFromOutput:readerVideoTrackOutput reader:reader];
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
    if (reader.status == AVAssetReaderStatusReading) {
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
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(movieSampleBuffer);
    CVImageBufferRef movieFrame = CMSampleBufferGetImageBuffer(movieSampleBuffer);
    
    processingFrameTime = currentSampleTime;
    [self processMovieFrame:movieFrame withSampleTime:currentSampleTime];
}

- (void)processMovieFrame:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime {
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
        if ( (imageBufferWidth != bufferWidth) && (imageBufferHeight != bufferHeight) ) {
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
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
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
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
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
        
        CVPixelBufferUnlockBaseAddress(movieFrame, 0);
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
