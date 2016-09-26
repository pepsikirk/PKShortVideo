//
//  PKPlayerView.m
//  PKShortVideo
//
//  Created by jiangxincai on 16/9/26.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKPlayerView.h"
#import "PKPlayerManager.h"
@import AVFoundation;

@interface PKPlayerView ()

@property (strong, nonatomic) UIImageView *playerImageView;

@property (nonatomic, strong) UIImage *previewImage;

@property (nonatomic,weak) AVPlayer *player;

@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) AVPlayerItem *playerItem;

@property (assign, nonatomic ,readwrite) BOOL isPlayable;
@property (nonatomic ,assign ,readwrite) BOOL isPlaying;

@property (nonatomic, strong) NSString *videoPath;
@property (nonatomic, strong) NSString *uniqueID;

@property (nonatomic ,assign) BOOL needPlay;

@end

@implementation PKPlayerView



#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame videoPath:(NSString *)videoPath previewImage:(UIImage *)previewImage {
    NSParameterAssert(videoPath != nil);
    NSParameterAssert(previewImage != nil);
    
    self = [super initWithFrame:frame];
    if (self) {
        if (videoPath) {
            [self setVideoPath:videoPath];
        }
        _isPlaying = NO;
        _isPlayable = YES;
        _previewImage = previewImage;

        [self addSubview:self.playerImageView];
        [self.playerImageView.layer addSublayer:self.playerLayer];
    }
    return self;
}

- (void)dealloc {
    _videoPath = nil;
    _playerLayer = nil;
    _player = nil;
    _playerItem = nil;
    _previewImage = nil;
    _playerImageView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - Setters

- (void)setVideoPath:(NSString *)videoPath {
    _videoPath = [videoPath copy];
    _playerLayer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:nil];
    self.isPlayable = asset.playable;
    
    NSArray *requestedKeys = @[@"playable"];
    
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler: ^{
        dispatch_async( dispatch_get_main_queue(), ^{
            [self prepareToPlayAsset:asset withKeys:requestedKeys];
        });
    }];
}

- (void)setPreviewImage:(UIImage *)previewImage {
    _previewImage = previewImage;
    if (self.playerImageView) {
        self.playerImageView.image = previewImage;
    }
    _playerLayer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark Prepare to play asset, URL

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys {
    for (NSString *thisKey in requestedKeys) {
        NSError *error = nil;
        AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
        if (keyStatus == AVKeyValueStatusFailed) {
            NSLog(@"加载失败");
            return;
        }
    }
    if (!asset.playable) {
        NSLog(@"不能播放");
        return;
    }
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    [self creatPlayer];
}



#pragma mark - Public

- (void)play {
    if (!self.playerItem) {
        if (!self.player) {
            self.needPlay = YES;
            return;
        }
    } else {
        [self creatPlayer];
    }
    
    [self.player play];
    self.isPlaying = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shortVideoItemPlayerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
}

- (void)stop {
    if (self.player) {
        [self.player pause];
        self.isPlaying = NO;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    }
}



#pragma mark - Private

- (void)creatPlayer {
    self.player = [[PKPlayerManager sharedManager] getAVQueuePlayWithPlayerItem:self.playerItem uniqueID:self.uniqueID];
    self.playerLayer.player = self.player;
    if (self.needPlay) {
        self.needPlay = NO;
        [self play];
    }
}



#pragma mark - Notification

- (void)shortVideoItemPlayerItemDidReachEnd:(NSNotification *)notification{
    AVPlayerItem *item = notification.object;
    if (self.player.currentItem == item) {
        [self.player seekToTime:kCMTimeZero];
        [self.player play];
    }
}



#pragma mark - Getter

- (NSString *)uniqueID {
    if (!_uniqueID) {
        _uniqueID = [NSProcessInfo processInfo].globallyUniqueString;
    }
    return _uniqueID;
}

- (UIImageView *)playerImageView {
    if (!_playerImageView) {
        _playerImageView = [[UIImageView alloc] initWithImage:self.previewImage];
        _playerImageView.backgroundColor = [UIColor blackColor];
        _playerImageView.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
        _playerImageView.contentMode = UIViewContentModeScaleAspectFill;
        _playerImageView.clipsToBounds = YES;
    }
    return _playerImageView;
}

- (AVPlayerLayer *)playerLayer {
    if (!_playerLayer) {
        _playerLayer = [AVPlayerLayer layer];
        _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.playerLayer.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
    }
    return _playerLayer;
}


@end
