# PKShortVideo
# [中文介绍](#Chinese_Introduction)
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/pepsikirk/PKShortVideo/blob/master/LICENSE) 
[![CocoaPods](http://img.shields.io/cocoapods/v/PKShortVideo.svg)](http://cocoapods.org/pods/PKShortVideo) 
[![CocoaPods](http://img.shields.io/cocoapods/p/PKShortVideo.svg?style=flat)](http://cocoapods.org/pods/PKShortVideo) 
[![Support](https://img.shields.io/badge/support-iOS%207%2B%20-blue.svg?style=flat)](https://www.apple.com/nl/ios/)

A video library like WeChat short video for iOS. 

Related Articles：[iOS仿微信小视频功能开发优化记录](http://www.jianshu.com/p/6d35bb53f4ac)

![sc1](https://raw.githubusercontent.com/pepsikirk/PKShortVideo/master/Screenshots/gif.gif)

#Features

- Short video playback in chat interface, the use of GPUImage-based OpenGL ES hardware accelerated playback video
- Short video  can click to enlarge playback, using the AVPlayer
- Provide a short video capture, to support custom resolution video capture, has a basic style, and provides the basis of switching cameras, recording, playback, re-recording function, the use of AVCaptureSession + AVCaptureVideoDataOutput and AVCaptureAudioDataOutput direct output video

#Installation

Import <YYKit/YYKit.h>.
1. Add pod 'PKShortVideo' to your Podfile.
2. Run pod install or pod update.
3. Import "PKShortVideo.h".

#Usage

>When Video recording, OutputFilePath parameters for the recording after the completion of the output video file path, OutputSize is the output video resolution.
> 

##Use default UI interface to record video (PKRecordShortVideoViewController)

###Enter the recording interface

```objc
PKRecordShortVideoViewController *viewController = [[PKRecordShortVideoViewController alloc] initWithOutputFilePath:path outputSize:CGSizeMake(320, 240) themeColor:[UIColor colorWithRed:0/255.0 green:153/255.0 blue:255/255.0 alpha:1]];
viewController.delegate = self;
[self presentViewController:viewController animated:YES completion:nil];
```

###Record complete callback

```objc
#pragma mark - PKRecordShortVideoDelegate
- (void)didFinishRecordingToOutputFilePath:(NSString *)outputFilePath {
    [self.demoData addShortVideoMediaMessageWithVideoPath:outputFilePath];
    [self finishSendingMessageAnimated:YES];
}
```

##When you use a custom UI to record video (PKShortVideoRecorder)

###Creates a recording object

```objc
self.recorder = [[PKShortVideoRecorder alloc] initWithOutputFilePath:self.outputFilePath outputSize:self.outputSize];
self.recorder.delegate = self;
AVCaptureVideoPreviewLayer *previewLayer = [self.recorder previewLayer];
previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
previewLayer.frame = CGRectMake(0, 44, kScreenWidth, PKPreviewLayerHeight);
[self.view.layer insertSublayer:previewLayer atIndex:0];
```

###Start preview camera work

```objc
[self.recorder startRunning];
```

###Swap front and back camera

```objc
[self.recorder swapFrontAndBackCameras];
```

###Start Recording

```objc
[self.recorder startRecording];
```

###Stop Recording

```objc
[self.recorder stopRecording];
```

###Video recorded successful callback

```objc
- (void)recorder:(PKShortVideoRecorder *)recorder didFinishRecordingToOutputFilePath:(NSString *)outputFilePath error:(NSError *)error {
}
```

>When Video playback, OutputFilePath parameters for the recording is completed after the output video file path, previewImage is a video preview.
> 

##Chat interface to play (due to different chat framework, here only JSQMessagesViewController to demonstrate)

###Chat object creation

```objc
- (void)addShortVideoMediaMessageWithVideoPath:(NSString *)videoPath  playType:(PKPlayType)type {
    switch (type) {
        case PKPlayTypeOpenGL: {
            PKShortVideoItem *videoItem = [[PKShortVideoItem alloc] initWithVideoPath:videoPath previewImage:[UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:videoPath]]];
            JSQMessage *videoMessage = [JSQMessage messageWithSenderId:kJSQDemoAvatarIdSquires
                                                           displayName:kJSQDemoAvatarDisplayNameSquires
                                                                 media:videoItem];
            [self.messages addObject:videoMessage];
        }
            break;
            
        case PKPlayTypeAVPlayer: {
            PKShortVideoItem2 *videoItem = [[PKShortVideoItem2 alloc] initWithVideoPath:videoPath previewImage:[UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:videoPath]]];
            JSQMessage *videoMessage = [JSQMessage messageWithSenderId:kJSQDemoAvatarIdSquires
                                                           displayName:kJSQDemoAvatarDisplayNameSquires
                                                                 media:videoItem];
            [self.messages addObject:videoMessage];
        }
            break;
    }

}
```

###The chat object is attached to the internal implementation of the media object

> You can use the PKChatMessagePlayerView based on OpenGL and PKPlayerView based on AVPlayer, because PKChatMessagePlayerView to achieve the realization of OpenGL by reflecting the current is not stable, it is recommended to use PKPlayerView, using the interface exactly the same.
> 

```objc
CGSize size = [self mediaViewDisplaySize];
self.playerView = [[PKPlayerView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) videoPath:self.videoPath previewImage:self.image];
```

> If the demand strategy is very complex, need to determine whether the group or friends, a variety of network conditions, whether to download or automatically play, still need to customize the chat object attached media objects, PKChatMessagePlayerView only in the presence of video playback.
>  

```objc
- (void)play {
    [self.playerView play];
}

- (void)pause {
    [self.playerView stop];
}
```

###Chat interface control to achieve

> For performance reasons, the best in the chat interface to do when the display is played, do not show the time to stop playing.
>

```objc
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        [item pause];
    }
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        [item play];
    }
}
```

##Click to Full Screen play

```objc
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        PKFullScreenPlayerViewController *viewController = [[PKFullScreenPlayerViewController alloc] initWithVideoPath:item.videoPath previewImage:[UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:item.videoPath]]];
        [self presentViewController:viewController animated:NO completion:NULL];
    }
}
```

#Requirements
This library requires  `iOS 7.0` and `Xcode 7.0`.

#License
PKShortVideo is provided under the MIT license. See LICENSE file for details.

# Contact
Weibo: [@-湛蓝_](http://weibo.com/u/1776530813/)

Email: [pepsikirk@gmail.com](mailto:pepsikirk@gmail.com)

==============

#<a id="Chinese_Introduction"></a>中文介绍

这是一个类似微信小视频功能的框架。

相关文章介绍：[iOS仿微信小视频功能开发优化记录](http://www.jianshu.com/p/6d35bb53f4ac)

![sc1](https://raw.githubusercontent.com/pepsikirk/PKShortVideo/master/Screenshots/gif.gif)

#特性

- 小视频聊天界面播放，使用基于 GPUImage 的 OpenGL ES 硬件加速播放视频
- 小视频可以点击放大播放，使用了 AVPlayer
- 提供小视频拍摄，能够支持自定义分辨率视频拍摄，有着基础样式，并提供了基础的切换摄像头、录制、播放、重新录制的功能，使用了 AVCaptureSession + AVCaptureVideoDataOutput和AVCaptureAudioDataOutput直接输出视频

#安装

1. 在 Podfile 中添加 pod 'PKShortVideo'。
2. 执行 pod install 或 pod update。
3. 导入 #import "PKShortVideo.h"。

#简单用法

> 视频录制时，OutputFilePath参数为录制完成后输出的视频文件路径，OutputSize是输出视频的分辨率
> 

##简单使用自带UI界面时，录制视频(PKRecordShortVideoViewController)

###进入录制界面

```objc
//跳转默认录制视频ViewController
PKRecordShortVideoViewController *viewController = [[PKRecordShortVideoViewController alloc] initWithOutputFilePath:path outputSize:CGSizeMake(320, 240) themeColor:[UIColor colorWithRed:0/255.0 green:153/255.0 blue:255/255.0 alpha:1]];
//通过代理回调
viewController.delegate = self;
[self presentViewController:viewController animated:YES completion:nil];
```

###录制完成回调

```objc
#pragma mark - PKRecordShortVideoDelegate
//视频拍摄完成输出图片
- (void)didFinishRecordingToOutputFilePath:(NSString *)outputFilePath {
    //自定义的生成小视频聊天对象方法
    [self.demoData addShortVideoMediaMessageWithVideoPath:outputFilePath];
    //JSQMessagesViewController的完成发送滚动到底端方法
    [self finishSendingMessageAnimated:YES];
}
```

##自定义UI时录制时，录制视频(PKShortVideoRecorder)

###创建录制对象

```objc
//创建视频录制对象
self.recorder = [[PKShortVideoRecorder alloc] initWithOutputFilePath:self.outputFilePath outputSize:self.outputSize];
//通过代理回调
self.recorder.delegate = self;
//录制时需要获取预览显示的layer，根据情况设置layer属性，显示在自定义的界面上
AVCaptureVideoPreviewLayer *previewLayer = [self.recorder previewLayer];
previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
previewLayer.frame = CGRectMake(0, 44, kScreenWidth, PKPreviewLayerHeight);
[self.view.layer insertSublayer:previewLayer atIndex:0];
```

###开始预览摄像头工作

```objc
//开始预览摄像头工作
[self.recorder startRunning];
```

###切换前后摄像头

```objc
//切换前后摄像头
[self.recorder swapFrontAndBackCameras];
```

###开始录制

```objc
//开始录制视频
[self.recorder startRecording];
```

###停止录制

```objc
//停止录制
[self.recorder stopRecording];
```

###视频录制成功回调

```objc
//视频录制结束回调
- (void)recorder:(PKShortVideoRecorder *)recorder didFinishRecordingToOutputFilePath:(NSString *)outputFilePath error:(NSError *)error {
//录制成功返回路径，录制失败返回错误对象
}
```

> 视频播放时，OutputFilePath参数为录制完成后输出的视频文件路径，previewImage是视频预览图
> 

##聊天界面播放(由于聊天框架不同，这里只用JSQMessagesViewController进行示范)

###聊天对象创建

```objc
- (void)addShortVideoMediaMessageWithVideoPath:(NSString *)videoPath  playType:(PKPlayType)type {
    //PKShortVideoItem为遵循JSQMessagesViewController的规范创建的媒体(非文字)类型
    //previewImage参数为视频的预览图片
    
    switch (type) {
        case PKPlayTypeOpenGL: {
            PKShortVideoItem *videoItem = [[PKShortVideoItem alloc] initWithVideoPath:videoPath previewImage:[UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:videoPath]]];
            //创建message对象
            JSQMessage *videoMessage = [JSQMessage messageWithSenderId:kJSQDemoAvatarIdSquires
                                                           displayName:kJSQDemoAvatarDisplayNameSquires
                                                                 media:videoItem];
            //把创建聊天对象加入聊天数组
            [self.messages addObject:videoMessage];
        }
            break;
            
        case PKPlayTypeAVPlayer: {
            PKShortVideoItem2 *videoItem = [[PKShortVideoItem2 alloc] initWithVideoPath:videoPath previewImage:[UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:videoPath]]];
            //创建message对象
            JSQMessage *videoMessage = [JSQMessage messageWithSenderId:kJSQDemoAvatarIdSquires
                                                           displayName:kJSQDemoAvatarDisplayNameSquires
                                                                 media:videoItem];
            //把创建聊天对象加入聊天数组
            [self.messages addObject:videoMessage];
        }
            break;
    }

}
```

###聊天对象附属的媒体对象内部实现

> 可以使用基于 OpenGL 的 PKChatMessagePlayerView 和基于 AVPlayer 的 PKPlayerView ,由于 PKChatMessagePlayerView 实现的 OpenGL 的实现通过反映目前并不稳定，推荐使用 PKPlayerView ，使用接口完全一致。
> 

```objc
//当前尺寸
CGSize size = [self mediaViewDisplaySize];
//实例化播放view
self.playerView = [[PKPlayerView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) videoPath:self.videoPath previewImage:self.image];
```

> 如果需求策略非常复杂，如需判断是群还是好友、各种网络情况下，是否下载或者自动播放，仍然需要自定义聊天对象附属媒体对象，PKChatMessagePlayerView仅可在视频存在情况下播放使用
>  

```objc
//开始播放小视频
- (void)play {
    [self.playerView play];
}
//结束播放视频
- (void)pause {
    [self.playerView stop];
}
```

###聊天界面控制实现

> 出于性能考虑，最好在聊天界面处理做到显示的时候才播放，不显示的时候停止播放
>

```objc
//将要结束显示时停止播放
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        [item pause];
    }
}

//将要显示时播放
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        [item play];
    }
}
```

##点击全屏播放

```objc
//点击消息是跳转播放
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath {
    JSQMessage *message = self.demoData.messages[indexPath.item];
    //判断媒体消息类型
    if ([message.media isKindOfClass:[PKShortVideoItem class]]) {
        PKShortVideoItem *item = (PKShortVideoItem *)message.media;
        //跳转全屏播放小视频界面
        PKFullScreenPlayerViewController *viewController = [[PKFullScreenPlayerViewController alloc] initWithVideoPath:item.videoPath previewImage:[UIImage pk_previewImageWithVideoURL:[NSURL fileURLWithPath:item.videoPath]]];
        [self presentViewController:viewController animated:NO completion:NULL];
    }
}
```

#要求
本框架最低支持 `iOS 7.0` 和 `Xcode 7.0`。

#许可证
PKShortVideo 使用 MIT 许可证，详情见 LICENSE 文件。

# 联系方式
Weibo: [@-湛蓝_](http://weibo.com/u/1776530813/)

Email: [pepsikirk@gmail.com](mailto:pepsikirk@gmail.com)
