//
//  PKShortVideoTests.m
//  PKShortVideoTests
//
//  Created by pepsikirk on 15/12/30.
//  Copyright © 2015年 pepsikirk. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#import "PKShortVideoSession.h"
#import "PKShortVideoRecorder.h"
#import "PKPlayerManager.h"

@interface PKShortVideoTests : XCTestCase <PKShortVideoSessionDelegate>

@property (nonatomic, strong) XCTestExpectation *failureExpectation;

@end

@implementation PKShortVideoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMissingAudioFormatDoesNotCrashOrInitializeAudioTrack {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSProcessInfo processInfo].globallyUniqueString];
    PKShortVideoSession *session = [[PKShortVideoSession alloc] initWithTempFilePath:path];

    XCTAssertNotNil(session);
    XCTAssertNoThrow([session addAudioTrackWithSourceFormatDescription:NULL settings:@{}]);
    XCTAssertFalse(session.audioInitialized);
}

- (void)testPreparingWithoutVideoTrackReportsFailure {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSProcessInfo processInfo].globallyUniqueString];
    PKShortVideoSession *session = [[PKShortVideoSession alloc] initWithTempFilePath:path];
    self.failureExpectation = [self expectationWithDescription:@"session failure callback"];
    session.delegate = self;

    [session prepareToRecord];

    [self waitForExpectations:@[self.failureExpectation] timeout:1.0];
}

- (void)testOddFullScreenOutputSizeUsesMacroblockAlignedH264Dimensions {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSProcessInfo processInfo].globallyUniqueString];
    PKShortVideoRecorder *recorder = [[PKShortVideoRecorder alloc] initWithOutputFilePath:path outputSize:CGSizeMake(375, 667)];

    NSDictionary *videoSettings = [recorder valueForKey:@"videoCompressionSettings"];

    XCTAssertEqual([videoSettings[AVVideoWidthKey] integerValue], 656);
    XCTAssertEqual([videoSettings[AVVideoHeightKey] integerValue], 368);
    XCTAssertEqual([videoSettings[AVVideoWidthKey] integerValue] % 16, 0);
    XCTAssertEqual([videoSettings[AVVideoHeightKey] integerValue] % 16, 0);

    [recorder stopRunning];
}

- (void)testRecordingConfigurationOverridesEncoderBitRatesAndIsCopied {
    PKShortVideoRecorderConfiguration *configuration = [PKShortVideoRecorderConfiguration new];
    configuration.videoBitRate = 1500000;
    configuration.audioBitRatePerChannel = 64000;
    configuration.captureSessionPreset = AVCaptureSessionPreset1280x720;

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSProcessInfo processInfo].globallyUniqueString];
    PKShortVideoRecorder *recorder = [[PKShortVideoRecorder alloc] initWithOutputFilePath:path
                                                                                 outputSize:CGSizeMake(375, 667)
                                                                     recordingConfiguration:configuration];
    configuration.videoBitRate = 1;

    NSDictionary *videoSettings = [recorder valueForKey:@"videoCompressionSettings"];
    NSDictionary *videoCompressionProperties = videoSettings[AVVideoCompressionPropertiesKey];
    NSDictionary *audioSettings = [recorder valueForKey:@"audioCompressionSettings"];

    XCTAssertEqual([videoCompressionProperties[AVVideoAverageBitRateKey] integerValue], 1500000);
    XCTAssertEqual([audioSettings[AVEncoderBitRatePerChannelKey] integerValue], 64000);
    XCTAssertEqual(recorder.recordingConfiguration.videoBitRate, 1500000);
    XCTAssertEqualObjects(recorder.recordingConfiguration.captureSessionPreset, AVCaptureSessionPreset1280x720);

    PKShortVideoRecorderConfiguration *returnedConfiguration = recorder.recordingConfiguration;
    returnedConfiguration.videoBitRate = 1;
    XCTAssertEqual(recorder.recordingConfiguration.videoBitRate, 1500000);

    [recorder stopRunning];
}

- (void)testPlayerManagerCreatesPlayersOnDemandForPKPlayerViewUsage {
    PKPlayerManager *manager = [PKPlayerManager sharedManager];
    [manager removeAllPlayer];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:@"/tmp/PKShortVideo-player-manager-test.mp4"]];
    AVPlayer *player = [manager getAVQueuePlayWithPlayerItem:item uniqueID:@"PKShortVideo-player-manager-test"];

    XCTAssertNotNil(player);
    XCTAssertEqual(player.currentItem, item);

    [manager removeAllPlayer];
}

- (void)testPlayerManagerRemovesStaleMappingWhenReusingPooledPlayer {
    PKPlayerManager *manager = [PKPlayerManager sharedManager];
    [manager removeAllPlayer];
    manager.playerMaxCount = 1;

    AVPlayerItem *firstItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:@"/tmp/PKShortVideo-first-player.mp4"]];
    AVPlayerItem *secondItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:@"/tmp/PKShortVideo-second-player.mp4"]];
    AVPlayer *firstPlayer = [manager getAVQueuePlayWithPlayerItem:firstItem uniqueID:@"PKShortVideo-first-player"];
    AVPlayer *secondPlayer = [manager getAVQueuePlayWithPlayerItem:secondItem uniqueID:@"PKShortVideo-second-player"];

    NSDictionary *playerMapping = [manager valueForKey:@"playerDict"];
    XCTAssertEqual(firstPlayer, secondPlayer);
    XCTAssertNil(playerMapping[@"PKShortVideo-first-player"]);
    XCTAssertEqual(playerMapping[@"PKShortVideo-second-player"], secondPlayer);

    manager.playerMaxCount = 8;
    [manager removeAllPlayer];
}

- (void)sessionDidFinishPreparing:(PKShortVideoSession *)session {
    XCTFail(@"A session without a video track must not prepare successfully");
}

- (void)session:(PKShortVideoSession *)session didFailWithError:(NSError *)error {
    XCTAssertNotNil(error);
    [self.failureExpectation fulfill];
}

- (void)sessionDidFinishRecording:(PKShortVideoSession *)session {
    XCTFail(@"A session without a video track must not finish recording");
}

@end
