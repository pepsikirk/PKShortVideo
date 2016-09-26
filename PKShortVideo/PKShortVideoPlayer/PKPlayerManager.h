//
//  PKPlayerManager.h
//  PKShortVideo
//
//  Created by jiangxincai on 16/9/26.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <Foundation/Foundation.h>
@class AVPlayer;
@class AVPlayerItem;

@interface PKPlayerManager : NSObject

/**
 *  播放器最大数量，默认8个，不建议少于6个，会导致显示问题
 */
@property (assign, nonatomic) NSUInteger playerMaxCount;

+ (instancetype)sharedManager;

/**
 *  获取 AVPlayer 对象
 *
 *  @param item     PlayerItem
 *  @param uniqueID 唯一ID
 *
 *  @return 返回 player 对象
 */
- (AVPlayer *)getAVQueuePlayWithPlayerItem:(AVPlayerItem *)item uniqueID:(NSString *)uniqueID;

/**
 *  播放之前要创建 Player 对象，默认创建8个复用
 */
- (void)creatMessagePlayer;

/**
 *  一般来说退出聊天页面可以释放缓存的 AVPlayer 对象减少内存消耗
 */
- (void)removeAllPlayer;

/**
 *  移除 Player 对象通过唯一ID
 *
 *  @param uniqueID <#uniqueID description#>
 */
- (void)removePlayerWithuniqueID:(NSString *)uniqueID;

@end
