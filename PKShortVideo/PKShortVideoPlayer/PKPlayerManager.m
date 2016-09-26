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
        
        _playerMaxCount = 8;
    }
    return self;
}

- (AVPlayer *)getAVQueuePlayWithPlayerItem:(AVPlayerItem *)item uniqueID:(NSString *)uniqueID {
    //通过uniqueID取Player对象
    AVPlayer *player = self.playerDict[uniqueID];
    if (player) {
        //对象不等时替换player对象的item
        if (player.currentItem != item) {
            [player replaceCurrentItemWithPlayerItem:item];
        }
        return player;
    } else {
        //未在界面创建小视频时返回nil
        if (!self.playerArray.count) {
            return nil;
        }
        if (self.playerArray.count <= self.playerIndex) {
            self.playerIndex = 0;
        }
        //按顺序平均分配player数组里面的player
        AVPlayer *player = self.playerArray[self.playerIndex];
        if (self.playerIndex == self.playerMaxCount - 1) {
            self.playerIndex = 0;
        } else {
            self.playerIndex = self.playerIndex + 1;
        }
        [player replaceCurrentItemWithPlayerItem:item];
        //缓存play可以快速获取对应的player
        [self.playerDict setObject:player forKey:uniqueID];
        
        return player;
    }
}

- (void)creatMessagePlayer {
    if (self.playerArray.count > 0) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (NSInteger i = 0; i < self.playerMaxCount ; i++) {
            AVPlayer *player = [AVPlayer new];
            player.volume = 0;
            [self.playerArray addObject:player];
        }
    });
}

- (void)removeAllPlayer {
    [self.playerDict removeAllObjects];
    for (AVPlayer *player in self.playerArray) {
        [PKPlayerManager removePlayer:player];
    }
    [self.playerArray removeAllObjects];
}

- (void)removePlayerWithuniqueID:(NSString *)uniqueID {
    AVPlayer *player = self.playerDict[uniqueID];
    if (player) {
        [PKPlayerManager removePlayer:player];
        [self.playerArray removeObject:player];
    }
}

+ (void)removePlayer:(AVPlayer *)player {
    [player pause];
    [player.currentItem cancelPendingSeeks];
    [player.currentItem.asset cancelLoading];
    [player replaceCurrentItemWithPlayerItem:nil];
}


@end
