//
//  PKPlayerManager.m
//  PKShortVideo
//
//  Created by TYM01 on 16/9/26.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKPlayerManager.h"
@import AVFoundation;

static NSInteger const PKPlayerCount = 8;

@interface PKPlayerManager ()

@property (strong, nonatomic) NSMutableDictionary *playerDict;
@property (strong, nonatomic) NSMutableArray *playerArray;
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
    }
    return self;
}

- (AVPlayer *)getAVQueuePlayWithPlayerItem:(AVPlayerItem *)item uniqueID:(NSString *)uniqueID {
    AVPlayer *player = self.playerDict[uniqueID];
    if (player) {
        if (player.currentItem != item) {
            [player replaceCurrentItemWithPlayerItem:item];
        }
        return player;
    } else {
        if (!self.playerArray.count) {
            return nil;
        }
        if (self.playerArray.count <= self.playerIndex) {
            self.playerIndex = 0;
        }
        AVPlayer *player = self.playerArray[self.playerIndex];
        if (self.playerIndex == PKPlayerCount - 1) {
            self.playerIndex = 0;
        } else {
            self.playerIndex = self.playerIndex + 1;
        }
        [player replaceCurrentItemWithPlayerItem:item];
        
        [self.playerDict setObject:player forKey:uniqueID];
        
        return player;
    }
}

- (void)creatMessagePlayer {
    if (self.playerArray.count > 0) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (NSInteger i = 0; i < PKPlayerCount ; i++) {
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
