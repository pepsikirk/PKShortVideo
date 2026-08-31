//
//  PKShortVideoWriter.h
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/14.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PKShortVideoRecorderErrorDomain;

typedef NS_ENUM(NSInteger, PKShortVideoRecorderErrorCode) {
    PKShortVideoRecorderErrorCodeUnknown = 1,
    PKShortVideoRecorderErrorCodeCameraUnavailable,
    PKShortVideoRecorderErrorCodeExposureUnsupported,
    PKShortVideoRecorderErrorCodeInvalidExposure,
};

typedef void (^PKShortVideoRecorderExposureCompletion)(NSError * _Nullable error);

/**
 Encoder and capture options applied when a PKShortVideoRecorder is created.

 A value of 0 for either bit-rate property keeps the recorder's automatic
 default. The configuration is copied by the recorder, so callers should set
 all values before passing it to the initializer.
 */
@interface PKShortVideoRecorderConfiguration : NSObject <NSCopying>

/** A positive H.264 average bit rate in bits per second, or 0 for automatic. */
@property (nonatomic, assign) NSInteger videoBitRate;

/** A positive AAC bit rate per channel in bits per second, or 0 for automatic. */
@property (nonatomic, assign) NSInteger audioBitRatePerChannel;

/**
 An optional AVCaptureSessionPreset used for camera capture. If it is nil or
 unsupported by the active device, the recorder uses its existing output-size
 based preset selection.
 */
@property (nonatomic, copy, nullable) AVCaptureSessionPreset captureSessionPreset;

@end

@class PKShortVideoRecorder;

@protocol PKShortVideoRecorderDelegate <NSObject>

@required

- (void)recorderDidBeginRecording:(PKShortVideoRecorder *)recorder;
- (void)recorderDidEndRecording:(PKShortVideoRecorder *)recorder;
- (void)recorder:(PKShortVideoRecorder *)recorder didFinishRecordingToOutputFilePath:(nullable NSString *)outputFilePath error:(nullable NSError *)error;

@end



@class AVCaptureVideoPreviewLayer;

@interface PKShortVideoRecorder : NSObject

@property (nonatomic, weak) id<PKShortVideoRecorderDelegate> delegate;

/** The immutable-at-runtime configuration copied when this recorder was created. */
@property (nonatomic, copy, readonly) PKShortVideoRecorderConfiguration *recordingConfiguration;

/**
 Whether the recorder is preparing, recording, or finishing a recording.
 */
@property (nonatomic, assign, readonly, getter=isRecording) BOOL recording;

/**
 Whether the current capture session has an authorized microphone input.
 When this is NO, recordings contain video only.
 */
@property (nonatomic, assign, readonly, getter=isAudioRecordingAvailable) BOOL audioRecordingAvailable;

- (instancetype)initWithOutputFilePath:(NSString *)outputFilePath outputSize:(CGSize)outputSize;

/**
 Creates a recorder with optional encoder and capture configuration.

 The existing two-argument initializer keeps its original automatic settings.
 */
- (instancetype)initWithOutputFilePath:(NSString *)outputFilePath
                            outputSize:(CGSize)outputSize
                recordingConfiguration:(nullable PKShortVideoRecorderConfiguration *)recordingConfiguration;

- (void)startRunning;
- (void)stopRunning;

- (void)startRecording;
- (void)stopRecording;

- (void)swapFrontAndBackCameras;

/**
 Selects the best supported automatic exposure mode for the current camera.
 The completion is always delivered on the main queue.
 */
- (void)setContinuousAutoExposureWithCompletion:(nullable PKShortVideoRecorderExposureCompletion)completion;

/**
 Applies a custom exposure duration and ISO to the current camera.

 The values must be supported by the active camera format. The completion is
 delivered on the main queue after the exposure change synchronizes, or with
 an error when the camera is unavailable or does not support the request.
 */
- (void)setCustomExposureWithDuration:(CMTime)duration
                                   ISO:(float)ISO
                            completion:(nullable PKShortVideoRecorderExposureCompletion)completion;

- (AVCaptureVideoPreviewLayer *)previewLayer;

@end

NS_ASSUME_NONNULL_END
