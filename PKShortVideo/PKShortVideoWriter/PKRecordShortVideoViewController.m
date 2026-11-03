//
//  PKShortVideoViewController.m
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/14.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKRecordShortVideoViewController.h"
#import "PKShortVideoRecorder.h"
#import "PKShortVideoProgressBar.h"
#import <AVFoundation/AVFoundation.h>
#import "PKFullScreenPlayerViewController.h"
#import "UIImage+PKShortVideoPlayer.h"

#if defined(SWIFT_PACKAGE)
#import "resource_bundle_accessor.h"
#endif

static CGFloat const PKRecordButtonWidth = 90;

static UIImage *PKShortVideoImageNamed(NSString *name) {
#if defined(SWIFT_PACKAGE)
    return [UIImage imageNamed:name
                       inBundle:SWIFTPM_MODULE_BUNDLE
  compatibleWithTraitCollection:nil];
#else
    NSBundle *bundle = [NSBundle bundleForClass:[PKRecordShortVideoViewController class]];
    UIImage *image = [UIImage imageNamed:name
                              inBundle:bundle
         compatibleWithTraitCollection:nil];
    return image ?: [UIImage imageNamed:name];
#endif
}

@interface PKRecordShortVideoViewController() <PKShortVideoRecorderDelegate>

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
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation PKRecordShortVideoViewController

#pragma mark - Init 

- (instancetype)initWithOutputFilePath:(NSString *)outputFilePath outputSize:(CGSize)outputSize themeColor:(UIColor *)themeColor {
    self = [super init];
    if (self) {
        _themeColor = themeColor;
        _outputFilePath = outputFilePath;
        _outputSize = outputSize;
        _videoMaximumDuration = 6;
        _videoMinimumDuration = 1;
    }
    return self;
}

- (void)dealloc {
    [_recorder stopRunning];
}



#pragma mark - LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];
    
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    self.toolbar.barTintColor = [UIColor blackColor];
    self.toolbar.translucent = NO;
    [self.view addSubview:self.toolbar];
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleDone target:self action:@selector(cancelShoot)];
    cancelItem.tintColor = [UIColor whiteColor];
    
    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    
    UIBarButtonItem *transformItem = [[UIBarButtonItem alloc] initWithImage:PKShortVideoImageNamed(@"PK_Camera_Turn") style:UIBarButtonItemStyleDone target:self action:@selector(swapCamera)];
    transformItem.tintColor = [UIColor whiteColor];
    
    [self.toolbar setItems:@[cancelItem,flexible,transformItem]];
    
    //创建视频录制对象
    self.recorder = [[PKShortVideoRecorder alloc] initWithOutputFilePath:self.outputFilePath outputSize:self.outputSize];
    //通过代理回调
    self.recorder.delegate = self;
    //录制时需要获取预览显示的layer，根据情况设置layer属性，显示在自定义的界面上
    self.previewLayer = [self.recorder previewLayer];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    
    self.progressBar = [[PKShortVideoProgressBar alloc] initWithFrame:CGRectZero themeColor:self.themeColor duration:self.videoMaximumDuration];
    [self.view addSubview:self.progressBar];
    
    self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.recordButton setTitle:@"按住录" forState:UIControlStateNormal];
    [self.recordButton setTitleColor:self.themeColor forState:UIControlStateNormal];
    self.recordButton.titleLabel.font = [UIFont systemFontOfSize:17.0f];
    self.recordButton.frame = CGRectMake(0, 0, PKRecordButtonWidth, PKRecordButtonWidth);
    self.recordButton.layer.cornerRadius = PKRecordButtonWidth/2;
    self.recordButton.layer.borderWidth = 3;
    self.recordButton.layer.borderColor = self.themeColor.CGColor;
    self.recordButton.layer.masksToBounds = YES;
    [self recordButtonAction];
    [self.view addSubview:self.recordButton];
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect bounds = self.view.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat toolbarHeight = 44.0;
    CGFloat availableHeight = MAX(0, height - toolbarHeight);
    CGFloat previewHeight = MIN(ceilf(width * 0.75), ceilf(availableHeight * 0.55));
    CGFloat controlsTop = toolbarHeight + previewHeight;
    CGFloat controlsHeight = MAX(0, height - controlsTop);

    CGRect toolbarFrame = CGRectMake(0, 0, width, toolbarHeight);
    if (!CGRectEqualToRect(self.toolbar.frame, toolbarFrame)) {
        self.toolbar.frame = toolbarFrame;
    }

    CGRect previewFrame = CGRectMake(0, toolbarHeight, width, previewHeight);
    if (!CGRectEqualToRect(self.previewLayer.frame, previewFrame)) {
        self.previewLayer.frame = previewFrame;
    }

    CGRect progressBarFrame = CGRectMake(0, controlsTop - 5, width, 5);
    if (!CGRectEqualToRect(self.progressBar.frame, progressBarFrame)) {
        self.progressBar.frame = progressBarFrame;
    }

    CGPoint recordButtonCenter = CGPointMake(width / 2, controlsTop + controlsHeight / 3);
    if (!CGPointEqualToPoint(self.recordButton.center, recordButtonCenter)) {
        self.recordButton.center = recordButtonCenter;
    }

    if (self.playButton && self.refreshButton) {
        CGFloat buttonSpacing = (width - PKRecordButtonWidth) / 2;
        CGFloat accessoryButtonsY = controlsTop + controlsHeight * 2 / 3;
        CGPoint playButtonCenter = CGPointMake(buttonSpacing / 2, accessoryButtonsY);
        if (!CGPointEqualToPoint(self.playButton.center, playButtonCenter)) {
            self.playButton.center = playButtonCenter;
        }

        CGPoint refreshButtonCenter = CGPointMake(width - buttonSpacing / 2, accessoryButtonsY);
        if (!CGPointEqualToPoint(self.refreshButton.center, refreshButtonCenter)) {
            self.refreshButton.center = refreshButtonCenter;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.recorder startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.recorder stopRunning];
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
    [self.recorder stopRunning];
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)swapCamera {
    //切换前后摄像头
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
    //记录开始录制时间
    self.beginRecordTime = CACurrentMediaTime();
    //开始录制视频
    [self.recorder startRecording];
    //进度条开始动
    [self.progressBar play];
}

- (void)buttonStopRecording {
    //停止录制
    [self.recorder stopRecording];
}

- (void)sendVideo {
    [self dismissViewControllerAnimated:YES completion:^{
        [self.delegate didFinishRecordingToOutputFilePath:self.outputFilePath];
    }];
}

- (void)endRecordingWithPath:(NSString *)path failture:(BOOL)failture {
    [self.progressBar restore];

    [self.recordButton setTitle:@"按住拍摄" forState:UIControlStateNormal];
    
    if (failture) {
        [self showAlertWithText:@"生成视频失败"];
    } else {
        [self showAlertWithText:[NSString stringWithFormat:@"请长按超过%@秒钟",@(self.videoMinimumDuration)]];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    [self recordButtonAction];
}

- (void)showAlertWithText:(NSString *)text {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"录制小视频失败"
                                                                               message:text
                                                                        preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)invalidateTime {
    if ([self.stopRecordTimer isValid]) {
        [self.stopRecordTimer invalidate];
        self.stopRecordTimer = nil;
    }
}


#pragma mark - PKShortVideoRecorderDelegate

///录制开始回调
- (void)recorderDidBeginRecording:(PKShortVideoRecorder *)recorder {
    //录制长度限制到时间停止
    self.stopRecordTimer = [NSTimer scheduledTimerWithTimeInterval:self.videoMaximumDuration target:self selector:@selector(buttonStopRecording) userInfo:nil repeats:NO];
    
    [self.recordButton setTitle:@"" forState:UIControlStateNormal];
}

//录制结束回调
- (void)recorderDidEndRecording:(PKShortVideoRecorder *)recorder {
    //停止进度条
    [self.progressBar stop];
}

//视频录制结束回调
- (void)recorder:(PKShortVideoRecorder *)recorder didFinishRecordingToOutputFilePath:(NSString *)outputFilePath error:(NSError *)error {
    //解除自动锁屏限制
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    //取消计时器
    [self invalidateTime];
    
    if (error) {
        NSLog(@"视频拍摄失败: %@", error );
        [self endRecordingWithPath:outputFilePath failture:YES];
    } else {
        //当前时间
        CFAbsoluteTime nowTime = CACurrentMediaTime();
        if (self.beginRecordTime != 0 && nowTime - self.beginRecordTime < self.videoMinimumDuration) {
            [self endRecordingWithPath:outputFilePath failture:NO];
        } else {
            self.outputFilePath = outputFilePath;
            [self.recordButton setTitle:@"发送" forState:UIControlStateNormal];
            
            self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
            self.playButton.tintColor = self.themeColor;
            UIImage *playImage = [PKShortVideoImageNamed(@"PK_Play") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.playButton setImage:playImage forState:UIControlStateNormal];
            [self.playButton sizeToFit];
            [self.view addSubview:self.playButton];
            
            self.refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
            self.refreshButton.tintColor = self.themeColor;
            UIImage *refreshImage = [PKShortVideoImageNamed(@"PK_Delete") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.refreshButton setImage:refreshImage forState:UIControlStateNormal];
            [self.refreshButton sizeToFit];
            [self.view addSubview:self.refreshButton];
            [self.view setNeedsLayout];
            
            [self sendButtonAction];
        }

    }
}

@end
