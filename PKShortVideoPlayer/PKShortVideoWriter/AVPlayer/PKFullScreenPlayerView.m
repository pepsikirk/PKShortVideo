//
//  PKFullScreenPlayerView.m
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/4.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKFullScreenPlayerView.h"
@import AVFoundation;

@interface PKFullScreenPlayerView ()

@property (nonatomic, strong) NSString *videoPath;

@property (nonatomic, strong) UIImage *previewImage;

@property (nonatomic, strong) AVPlayer *player;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;

@end



@implementation PKFullScreenPlayerView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame videoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage {
    NSParameterAssert(videoPath != nil);
    NSParameterAssert(previewImage != nil);
    
    self = [super initWithFrame:frame];
    if (self) {
        _videoPath = videoPath;
        _previewImage = previewImage;
        
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
        
        __weak typeof(self)weakSelf = self;
        [asset loadValuesAsynchronouslyForKeys:@[@"playable"] completionHandler:^{
            dispatch_async( dispatch_get_main_queue(), ^{
                [weakSelf prepareToPlayAsset:asset];
            });
        }];
    }
    return self;
}

- (void)dealloc {
    [_player pause];
    [_player.currentItem cancelPendingSeeks];
    [_player.currentItem.asset cancelLoading];
    [_player replaceCurrentItemWithPlayerItem:nil];
    _player = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark Prepare to play asset, URL

- (void)prepareToPlayAsset:(AVAsset *)asset {
    NSError *error = nil;
    AVKeyValueStatus keyStatus = [asset statusOfValueForKey:@"playable" error:&error];
    if (keyStatus == AVKeyValueStatusFailed) {
        [self assetFailedToPrepareForPlayback:error];
        return;
    }
    
    if (!asset.playable) {
        NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"Item cannot be played" code:0 userInfo:nil];
        
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        return;
    }
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
    
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:_playerLayer];
    
    [self.player play];
}



#pragma mark - Error Handle

- (void)assetFailedToPrepareForPlayback:(NSError *)error {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Video cannot be played" message:@"Video cannot be played" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}



#pragma mark - Notification

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [self.player seekToTime:kCMTimeZero];
    
    [self.player play];
}



#pragma mark - Public

- (void)play {
    if (!self.player) {
        return;
    }
    [self.player play];
}

- (void)pause {
    if (!self.player) {
        return;
    }
    [self.player pause];
}


@end
