//
//  PKPlayerManager.h
//  PKShortVideo
//
//  Created by TYM01 on 16/9/26.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AVPlayer;
@class AVPlayerItem;

@interface PKPlayerManager : NSObject

+ (instancetype)sharedManager;

- (AVPlayer *)getAVQueuePlayWithPlayerItem:(AVPlayerItem *)item uniqueID:(NSString *)uniqueID;
- (void)creatMessagePlayer;
- (void)removeAllPlayer;
- (void)removePlayerWithuniqueID:(NSString *)uniqueID;

@end
