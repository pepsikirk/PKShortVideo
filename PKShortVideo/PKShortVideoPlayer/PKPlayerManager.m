//
//  PKPlayerManager.m
//  PKShortVideo
//
//  Created by jiangxincai on 16/9/26.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKPlayerManager.h"
@import AVFoundation;

@interface PKPlayerManager ()

/**
 *  AVPlayer 对象缓存快速取出字典
 */
@property (strong, nonatomic) NSMutableDictionary *playerDict;

/**
 *  AVPlayer 对象缓存排序数组
 */
@property (strong, nonatomic) NSMutableArray *playerArray;

/**
 *  AVPlayer 排序顺序
 */
@property (assign, nonatomic) NSInteger playerIndex;

@property (nonatomic, strong) dispatch_queue_t playerQueue;

@end

@implementation PKPlayerManager

+ (instancetype)sharedManager {
    static PKPlayerManager* module;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        module = [[PKPlayerManager alloc] init];
    });
    return module;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _playerDict = [NSMutableDictionary new];
        _playerArray = [NSMutableArray new];
        _playerQueue = dispatch_queue_create("com.PKShortVideo.playerManager", DISPATCH_QUEUE_SERIAL);
        
        _playerMaxCount = 8;
    }
    return self;
}

- (AVPlayer *)getAVQueuePlayWithPlayerItem:(AVPlayerItem *)item uniqueID:(NSString *)uniqueID {
    if (!item || uniqueID.length == 0) {
        return nil;
    }

    __block AVPlayer *player = nil;
    dispatch_sync(self.playerQueue, ^{
        //通过uniqueID取Player对象
        player = self.playerDict[uniqueID];
        if (player) {
            //对象不等时替换player对象的item
            if (player.currentItem != item) {
                [player replaceCurrentItemWithPlayerItem:item];
            }
            return;
        }

        //未在界面创建小视频时返回nil
        if (!self.playerArray.count) {
            return;
        }
        if (self.playerIndex >= self.playerArray.count) {
            self.playerIndex = 0;
        }
        //按顺序平均分配player数组里面的player
        player = self.playerArray[self.playerIndex];
        self.playerIndex = (self.playerIndex + 1) % self.playerArray.count;
        [player replaceCurrentItemWithPlayerItem:item];
        //缓存play可以快速获取对应的player
        self.playerDict[uniqueID] = player;
    });
    return player;
}

- (void)creatMessagePlayer {
    dispatch_sync(self.playerQueue, ^{
        if (self.playerArray.count > 0) {
            return;
        }
        for (NSInteger i = 0; i < self.playerMaxCount ; i++) {
            AVPlayer *player = [AVPlayer new];
            player.volume = 0;
            [self.playerArray addObject:player];
        }
    });
}

- (void)removeAllPlayer {
    dispatch_sync(self.playerQueue, ^{
        [self.playerDict removeAllObjects];
        for (AVPlayer *player in self.playerArray) {
            [PKPlayerManager removePlayer:player];
        }
        [self.playerArray removeAllObjects];
        self.playerIndex = 0;
    });
}

- (void)removePlayerWithuniqueID:(NSString *)uniqueID {
    if (uniqueID.length == 0) {
        return;
    }
    dispatch_sync(self.playerQueue, ^{
        AVPlayer *player = self.playerDict[uniqueID];
        if (player) {
            [PKPlayerManager removePlayer:player];
            //释放唯一 ID 映射，但保留播放器池容量供后续消息复用。
            [self.playerDict removeObjectForKey:uniqueID];
        }
    });
}

+ (void)removePlayer:(AVPlayer *)player {
    if (!player) {
        return;
    }
    [player pause];
    [player.currentItem cancelPendingSeeks];
    [player.currentItem.asset cancelLoading];
    [player replaceCurrentItemWithPlayerItem:nil];
}


@end
