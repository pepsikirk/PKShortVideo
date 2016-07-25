//
//  PKShortVideoWriter.m
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/14.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKShortVideoRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import "PKShortVideoSession.h"

typedef NS_ENUM( NSInteger, PKRecordingStatus ) {
    PKRecordingStatusIdle = 0,
    PKRecordingStatusStartingRecording,
    PKRecordingStatusRecording,
    PKRecordingStatusStoppingRecording,
}; 

@interface PKShortVideoRecorder() <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, PKShortVideoSessionDelegate>

@property (nonatomic, strong) NSString *outputFilePath;
@property (nonatomic, assign) CGSize outputSize;

@property (nonatomic, strong) NSString *tempFilePath;

@property (nonatomic, strong) dispatch_queue_t recorderQueue;

@property (nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) dispatch_queue_t audioDataOutputQueue;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;

@property (nonatomic, strong) AVCaptureConnection *audioConnection;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *cameraDevice;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) NSDictionary *videoCompressionSettings;
@property (nonatomic, strong) NSDictionary *audioCompressionSettings;

@property (nonatomic) CMFormatDescriptionRef outputVideoFormatDescription;
@property (nonatomic) CMFormatDescriptionRef outputAudioFormatDescription;

@property (nonatomic, assign) PKRecordingStatus recordingStatus;

@property (nonatomic, retain) PKShortVideoSession *assetSession;

@end

@implementation PKShortVideoRecorder

#pragma mark - Init

- (instancetype)initWithOutputFilePath:(NSString *)outputFilePath outputSize:(CGSize)outputSize {
    self = [super init];
    if (self) {
        _outputFilePath = outputFilePath;
        _outputSize = outputSize;
        
        _recorderQueue = dispatch_queue_create("com.PKShortVideoWriter.sessionQueue", DISPATCH_QUEUE_SERIAL );
        
        _audioDataOutputQueue = dispatch_queue_create("com.PKShortVideoWriter.audioOutput", DISPATCH_QUEUE_SERIAL );

        _videoDataOutputQueue = dispatch_queue_create("com.PKShortVideoWriter.videoOutput", DISPATCH_QUEUE_SERIAL );
        dispatch_set_target_queue(_videoDataOutputQueue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ) );
        
        _captureSession = [self setupCaptureSession];
        [self addDataOutputsToCaptureSession:self.captureSession];
    }
    return self;
}



#pragma mark - Running Session

- (void)startRunning {
    dispatch_sync(self.recorderQueue, ^{
        [self.captureSession startRunning];
    } );
}

- (void)stopRunning {
    dispatch_sync(self.recorderQueue, ^{
        [self stopRecording];
        [self.captureSession stopRunning];
    } );
}



#pragma mark - Recording

- (void)startRecording {
    @synchronized(self) {
        if (self.recordingStatus != PKRecordingStatusIdle) {
            NSLog(@"已经在录制了");
            return;
        }   
        [self transitionToRecordingStatus:PKRecordingStatusStartingRecording error:nil];
    }
    
    NSString *tempFileName = [NSProcessInfo processInfo].globallyUniqueString;
    self.tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[tempFileName stringByAppendingPathExtension:@"mp4"]];
    
    self.assetSession = [[PKShortVideoSession alloc] initWithTempFilePath:self.tempFilePath];
    self.assetSession.delegate = self;
    
    [self.assetSession addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription settings:self.videoCompressionSettings];
    [self.assetSession addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:self.audioCompressionSettings];
    
    [self.assetSession prepareToRecord];
}

- (void)stopRecording {
    @synchronized(self) {
        if (self.recordingStatus != PKRecordingStatusRecording){
            return;
        }
        [self transitionToRecordingStatus:PKRecordingStatusStoppingRecording error:nil];
    }
    [self.assetSession finishRecording];
}



#pragma mark - SwapCamera

- (void)swapFrontAndBackCameras {
    NSArray *inputs = self.captureSession.inputs;
    for ( AVCaptureDeviceInput *input in inputs ) {
        AVCaptureDevice *device = input.device;
        if ( [device hasMediaType:AVMediaTypeVideo] ) {
            AVCaptureDevicePosition position = device.position;
            AVCaptureDevice *newCamera = nil;
            AVCaptureDeviceInput *newInput = nil;
            
            if (position == AVCaptureDevicePositionFront) {
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            } else {
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            }
            
            newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];

            //beginConfiguration 确保改变不会立刻应用
            [self.captureSession beginConfiguration];
            
            [self.captureSession removeOutput:self.videoDataOutput];
            [self.captureSession removeOutput:self.audioDataOutput];

            [self.captureSession removeInput:input];
            [self.captureSession addInput:newInput];
            
            self.outputVideoFormatDescription = nil;
            self.outputAudioFormatDescription = nil;
            //开始生效
            [self.captureSession commitConfiguration];
            //重新加载
            [self addDataOutputsToCaptureSession:self.captureSession];
            break;
        }
    }
}



#pragma mark - Private methods

- (void)addDataOutputsToCaptureSession:(AVCaptureSession *)captureSession {
    self.videoDataOutput = [AVCaptureVideoDataOutput new];
    self.videoDataOutput.videoSettings = nil;
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
    
    self.audioDataOutput = [AVCaptureAudioDataOutput new];
    [self.audioDataOutput setSampleBufferDelegate:self queue:self.audioDataOutputQueue];
    
    [self addOutput:self.videoDataOutput toCaptureSession:self.captureSession];
    self.videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    [self addOutput:self.audioDataOutput toCaptureSession:self.captureSession];
    self.audioConnection = [self.audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    
    [self setCompressionSettings];
}

- (void)setCompressionSettings {
    NSInteger numPixels = self.outputSize.width * self.outputSize.height;
    //每像素比特
    CGFloat bitsPerPixel = 6.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                    AVVideoExpectedSourceFrameRateKey : @(30),
                                             AVVideoAverageBitRateKey : @(30) };
    
    self.videoCompressionSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                 AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                       AVVideoWidthKey : @(self.outputSize.height),
                                      AVVideoHeightKey : @(self.outputSize.width),
                       AVVideoCompressionPropertiesKey : compressionProperties };
    
    // 音频设置
    self.audioCompressionSettings = @{ AVEncoderBitRatePerChannelKey : @(28000),
                                                       AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                               AVNumberOfChannelsKey : @(1),
                                                     AVSampleRateKey : @(22050) };
}



#pragma mark - SampleBufferDelegate methods

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (connection == self.videoConnection){
        if (!self.outputVideoFormatDescription) {
            @synchronized(self) {
                CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                self.outputVideoFormatDescription = formatDescription;
            }
        } else {
            @synchronized(self) {
                if (self.recordingStatus == PKRecordingStatusRecording){
                    [self.assetSession appendVideoSampleBuffer:sampleBuffer];
                }
            }
        }
    } else if (connection == self.audioConnection ){
        if (!self.outputAudioFormatDescription) {
            @synchronized(self) {
                CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                self.outputAudioFormatDescription = formatDescription;
            }
        }
        @synchronized(self) {
            if (self.recordingStatus == PKRecordingStatusRecording){
                [self.assetSession appendAudioSampleBuffer:sampleBuffer];
            }
        }
    }
}

#pragma mark - PKAssetWriterDelegate methods

- (void)sessionDidFinishPreparing:(PKShortVideoRecorder *)writer {
    @synchronized(self) {
        if (self.recordingStatus != PKRecordingStatusStartingRecording){
            return;
        }
        [self transitionToRecordingStatus:PKRecordingStatusRecording error:nil];
    }
}

- (void)session:(PKShortVideoRecorder *)writer didFailWithError:(NSError *)error {
    @synchronized(self) {
        self.assetSession = nil;
        [self transitionToRecordingStatus:PKRecordingStatusIdle error:error];
    }
}

- (void)sessionDidFinishRecording:(PKShortVideoRecorder *)writer {
    @synchronized(self) {
        if ( self.recordingStatus != PKRecordingStatusStoppingRecording ) {
            return;
        }
    }
    self.assetSession = nil;
    
    @synchronized(self) {
        [self transitionToRecordingStatus:PKRecordingStatusIdle error:nil];
    }
}


#pragma mark - Recording State Machine

- (void)transitionToRecordingStatus:(PKRecordingStatus)newStatus error:(NSError *)error {
    PKRecordingStatus oldStatus = self.recordingStatus;
    self.recordingStatus = newStatus;
    
    if (newStatus != oldStatus){
        if (error && (newStatus == PKRecordingStatusIdle)){
            dispatch_async( dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    [self.delegate recorder:self didFinishRecordingToOutputFilePath:self.outputFilePath error:error];
                }
            });
        } else {
            error = nil;
            if (oldStatus == PKRecordingStatusStartingRecording && newStatus == PKRecordingStatusRecording){
                dispatch_async( dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        [self.delegate recorderDidBeginRecording:self];
                    }
                });
            } else if (oldStatus == PKRecordingStatusStoppingRecording && newStatus == PKRecordingStatusIdle) {
                dispatch_async( dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        [self.delegate recorderDidEndRecording:self];
                        [self.delegate recorder:self didFinishRecordingToOutputFilePath:self.tempFilePath error:nil];
                    }
                });
            }
        }
    }
}

#pragma mark - Capture Session Setup


- (AVCaptureSession *)setupCaptureSession {
    AVCaptureSession *captureSession = [AVCaptureSession new];
    
    if (self.isBigSize) {
        captureSession.sessionPreset = AVCaptureSessionPresetMedium;//360 x 480 小视频一般不会超过此尺寸
    } else {
        captureSession.sessionPreset = AVCaptureSessionPreset1280x720;//720 x 1280 小视频一般不会超过此尺寸
    }
    
    if (![self addDefaultCameraInputToCaptureSession:captureSession]){
        NSLog(@"加载摄像头失败");
    }
    if (![self addDefaultMicInputToCaptureSession:captureSession]){
        NSLog(@"加载麦克风失败");
    }
    
    return captureSession;
}

- (BOOL)addDefaultCameraInputToCaptureSession:(AVCaptureSession *)captureSession {
    NSError *error;
    AVCaptureDeviceInput *cameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] error:&error];
    
    if (error) {
        NSLog(@"配置摄像头输入错误: %@", [error localizedDescription]);
        return NO;
    } else {
        BOOL success = [self addInput:cameraDeviceInput toCaptureSession:captureSession];
        self.cameraDevice = cameraDeviceInput.device;
        return success;
    }
}

- (BOOL)addDefaultMicInputToCaptureSession:(AVCaptureSession *)captureSession {
    NSError *error;
    AVCaptureDeviceInput *micDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    if (error){
        NSLog(@"配置麦克风输入错误: %@", [error localizedDescription]);
        return NO;
    } else {
        BOOL success = [self addInput:micDeviceInput toCaptureSession:captureSession];
        return success;
    }
}

- (BOOL)addInput:(AVCaptureDeviceInput *)input toCaptureSession:(AVCaptureSession *)captureSession {
    if ([captureSession canAddInput:input]){
        [captureSession addInput:input];
        return YES;
    } else {
        NSLog(@"不能添加输入: %@", [input description]);
    }
    return NO;
}


- (BOOL)addOutput:(AVCaptureOutput *)output toCaptureSession:(AVCaptureSession *)captureSession {
    if ([captureSession canAddOutput:output]){
        [captureSession addOutput:output];
        return YES;
    } else {
        NSLog(@"不能添加输出 %@", [output description]);
    }
    return NO;
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            return device;
        }
    }
    return nil;
}


#pragma mark - Getter

- (AVCaptureVideoPreviewLayer *)previewLayer {
    if (!_previewLayer && _captureSession){
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    return _previewLayer;
}

- (BOOL)isBigSize {
    if (self.outputSize.width > 360 || self.outputSize.width/self.outputSize.height > 4/3) {
        return YES;
    } else {
        return NO;
    }
}


@end
