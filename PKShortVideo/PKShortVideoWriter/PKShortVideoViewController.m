//
//  PKShortVideoViewController.m
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/14.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKShortVideoViewController.h"
#import "PKShortVideoRecorder.h"
#import "PKShortVideoProgressBar.h"
#import "PKUtiltiies.h"
#import <AVFoundation/AVFoundation.h>
#import "PKFullScreenPlayerViewController.h"
#import "UIImage+PKShortVideoPlayer.h"

static CGFloat PKOtherButtonVarticalHeight = 0;
static CGFloat PKRecordButtonVarticalHeight = 0;
static CGFloat PKPreviewLayerHeight = 0;

static CGFloat const PKRecordButtonWidth = 90;

@interface PKShortVideoViewController() <PKShortVideoRecorderDelegate>

@property (nonatomic, strong) NSString *outputFilePath;
@property (nonatomic, assign) CGSize outputSize;

@property (nonatomic, strong) UIColor *themeColor;

@property (strong, nonatomic) NSTimer *stopRecordTimer;
@property (nonatomic, assign) CFAbsoluteTime beginRecordTime;

@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIButton *playButton;

@property (nonatomic, strong) PKShortVideoProgressBar *progressBar;
@property (nonatomic, strong) PKShortVideoRecorder *recorder;

@end

@implementation PKShortVideoViewController

#pragma mark - Init 

- (instancetype)initWithOutputFilePath:(NSString *)outputFilePath outputSize:(CGSize)outputSize themeColor:(UIColor *)themeColor {
    self = [super init];
    if (self) {
        _themeColor = themeColor;
        _outputFilePath = outputFilePath;
        _outputSize = outputSize;
        _videoDurationTime = 6;
    }
    return self;
}



#pragma mark - LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    PKPreviewLayerHeight = ceilf(3/4.0 * kScreenWidth);
    CGFloat spaceHeight = ceilf( (kScreenHeight - 44 - PKPreviewLayerHeight)/3 );
    PKRecordButtonVarticalHeight = ceilf( kScreenHeight - 2 * spaceHeight );
    PKOtherButtonVarticalHeight = ceilf( kScreenHeight - spaceHeight );
    
    self.view.backgroundColor = [UIColor blackColor];
    
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 44)];
    toolbar.barTintColor = [UIColor blackColor];
    toolbar.translucent = NO;
    [self.view addSubview:toolbar];
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleDone target:self action:@selector(cancelShoot)];
    cancelItem.tintColor = [UIColor whiteColor];
    
    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    
    UIBarButtonItem *transformItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"PK_Camera_turn"] style:UIBarButtonItemStyleDone target:self action:@selector(swapCamera)];
    transformItem.tintColor = [UIColor whiteColor];
    
    [toolbar setItems:@[cancelItem,flexible,transformItem]];
    
    self.recorder = [[PKShortVideoRecorder alloc] initWithOutputFilePath:self.outputFilePath outputSize:self.outputSize];
    self.recorder.delegate = self;
    
    AVCaptureVideoPreviewLayer *previewLayer = [self.recorder previewLayer];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.frame = CGRectMake(0, 44, kScreenWidth, PKPreviewLayerHeight);
    [self.view.layer insertSublayer:previewLayer atIndex:0];
    
    self.progressBar = [[PKShortVideoProgressBar alloc] initWithFrame:CGRectMake(0, 44 + PKPreviewLayerHeight - 5, kScreenWidth, 5) themeColor:self.themeColor duration:self.videoDurationTime];
    [self.view addSubview:self.progressBar];
    
    self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.recordButton setTitle:@"按住录" forState:UIControlStateNormal];
    [self.recordButton setTitleColor:self.themeColor forState:UIControlStateNormal];
    self.recordButton.titleLabel.font = [UIFont systemFontOfSize:17.0f];
    self.recordButton.frame = CGRectMake(0, 0, PKRecordButtonWidth, PKRecordButtonWidth);
    self.recordButton.center = CGPointMake(kScreenWidth/2, PKRecordButtonVarticalHeight);
    self.recordButton.layer.cornerRadius = PKRecordButtonWidth/2;
    self.recordButton.layer.borderWidth = 3;
    self.recordButton.layer.borderColor = self.themeColor.CGColor;
    self.recordButton.layer.masksToBounds = YES;
    [self recordButtonAction];
    [self.view addSubview:self.recordButton];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.recorder startRunning];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}



#pragma mark - Private 

- (void)cancelShoot {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)swapCamera {
    [self.recorder swapFrontAndBackCameras];
}

- (void)recordButtonAction {
    [self.recordButton removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    [self.recordButton addTarget:self action:@selector(toggleRecording) forControlEvents:UIControlEventTouchDown];
    [self.recordButton addTarget:self action:@selector(buttonStopRecording) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
}

- (void)sendButtonAction  {
    [self.recordButton removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    [self.recordButton addTarget:self action:@selector(sendVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.refreshButton addTarget:self action:@selector(refreshView) forControlEvents:UIControlEventTouchUpInside];
    [self.playButton addTarget:self action:@selector(playVideo) forControlEvents:UIControlEventTouchUpInside];
}

- (void)refreshView {
    [[NSFileManager defaultManager] removeItemAtPath:self.outputFilePath error:nil];
    [self.recordButton setTitle:@"按住录" forState:UIControlStateNormal];

    [self recordButtonAction ];
    [self.playButton removeFromSuperview];
    self.playButton = nil;
    [self.refreshButton removeFromSuperview];
    self.refreshButton = nil;
    
    [self.progressBar restore];
}

- (void)playVideo {
    UIImage *image = [UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:self.outputFilePath]];
    PKFullScreenPlayerViewController *vc = [[PKFullScreenPlayerViewController alloc] initWithVideoPath:self.outputFilePath previewImage:image];
    [self presentViewController:vc animated:NO completion:NULL];
}

- (void)toggleRecording {
    //静止自动锁屏
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.beginRecordTime = CACurrentMediaTime();

    [self.recorder startRecording];
    [self.progressBar play];
}

- (void)buttonStopRecording {
    [self.recorder stopRecording];
}

- (void)sendVideo {
    [self dismissViewControllerAnimated:YES completion:^{
        [self.delegate didFinishRecordingToOutputFilePath:self.outputFilePath];
    }];
}

- (void)endRecordingWithPath:(NSString *)Path failture:(BOOL)failture {
    [self.progressBar restore];

    [self.recordButton setTitle:@"按住拍摄" forState:UIControlStateNormal];
    
    if (failture) {
        [PKShortVideoViewController showAlertViewWithText:@"生成视频失败"];
    } else {
        [PKShortVideoViewController showAlertViewWithText:@"请长按超过1秒"];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:Path error:nil];
    [self recordButtonAction];
}

+ (void)showAlertViewWithText:(NSString *)text {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"录制小视频失败" message:text delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alertView show];
}

- (void)invalidateTime {
    if ([self.stopRecordTimer isValid]) {
        [self.stopRecordTimer invalidate];
        self.stopRecordTimer = nil;
    }
}


#pragma mark - PKShortVideoRecorderDelegate

- (void)recorderDidBeginRecording:(PKShortVideoRecorder *)recorder {
    self.stopRecordTimer = [NSTimer scheduledTimerWithTimeInterval:6.0 target:self selector:@selector(buttonStopRecording) userInfo:nil repeats:NO];
    
    [self.recordButton setTitle:@"" forState:UIControlStateNormal];
}

- (void)recorderDidEndRecording:(PKShortVideoRecorder *)recorder {
    [self.progressBar stop];
}

- (void)recorder:(PKShortVideoRecorder *)recorder didFinishRecordingToOutputFilePath:(NSString *)outputFilePath error:(NSError *)error {
    //解除自动锁屏限制
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [self invalidateTime];

    if (error) {
        NSLog(@"视频拍摄失败: %@", error );
        [self endRecordingWithPath:outputFilePath failture:YES];
    } else {
        CFAbsoluteTime nowTime = CACurrentMediaTime();
        if (self.beginRecordTime != 0 && nowTime - self.beginRecordTime < 1) {
            [self endRecordingWithPath:outputFilePath failture:NO];
        } else {
            self.outputFilePath = outputFilePath;
            [self.recordButton setTitle:@"发送" forState:UIControlStateNormal];
            
            self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
            self.playButton.tintColor = self.themeColor;
            UIImage *playImage = [[UIImage imageNamed:@"PK_Play"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.playButton setImage:playImage forState:UIControlStateNormal];
            [self.playButton sizeToFit];
            self.playButton.center = CGPointMake((kScreenWidth-PKRecordButtonWidth)/2/2, PKOtherButtonVarticalHeight);
            [self.view addSubview:self.playButton];
            
            self.refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
            self.refreshButton.tintColor = self.themeColor;
            UIImage *refreshImage = [[UIImage imageNamed:@"PK_Delete"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.refreshButton setImage:refreshImage forState:UIControlStateNormal];
            [self.refreshButton sizeToFit];
            self.refreshButton.center = CGPointMake(kScreenWidth-(kScreenWidth-PKRecordButtonWidth)/2/2, PKOtherButtonVarticalHeight);
            [self.view addSubview:self.refreshButton];
            
            [self sendButtonAction];
        }

    }
}

@end
