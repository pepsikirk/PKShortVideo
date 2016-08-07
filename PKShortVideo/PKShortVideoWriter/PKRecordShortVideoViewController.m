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

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

static CGFloat PKOtherButtonVarticalHeight = 0;
static CGFloat PKRecordButtonVarticalHeight = 0;
static CGFloat PKPreviewLayerHeight = 0;

static CGFloat const PKRecordButtonWidth = 90;

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
    
    UIBarButtonItem *transformItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"PK_Camera_Turn"] style:UIBarButtonItemStyleDone target:self action:@selector(swapCamera)];
    transformItem.tintColor = [UIColor whiteColor];
    
    [toolbar setItems:@[cancelItem,flexible,transformItem]];
    
    //创建视频录制对象
    self.recorder = [[PKShortVideoRecorder alloc] initWithOutputFilePath:self.outputFilePath outputSize:self.outputSize];
    //通过代理回调
    self.recorder.delegate = self;
    //录制时需要获取预览显示的layer，根据情况设置layer属性，显示在自定义的界面上
    AVCaptureVideoPreviewLayer *previewLayer = [self.recorder previewLayer];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.frame = CGRectMake(0, 44, kScreenWidth, PKPreviewLayerHeight);
    [self.view.layer insertSublayer:previewLayer atIndex:0];
    
    self.progressBar = [[PKShortVideoProgressBar alloc] initWithFrame:CGRectMake(0, 44 + PKPreviewLayerHeight - 5, kScreenWidth, 5) themeColor:self.themeColor duration:self.videoMaximumDuration];
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
    
//    dispatch_async(dispatch_get_main_queue(), ^{
        //开始预览摄像头工作
        [self.recorder startRunning];
//    });
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
        [PKRecordShortVideoViewController showAlertViewWithText:@"生成视频失败"];
    } else {
        [PKRecordShortVideoViewController showAlertViewWithText:[NSString stringWithFormat:@"请长按超过%@秒钟",@(self.videoMinimumDuration)]];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
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
