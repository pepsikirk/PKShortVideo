//
//  PKUtiltiies.m
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/17.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import "PKUtiltiies.h"

@implementation PKUtiltiies

+ (CGSize)screenSize {
    static CGSize size;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size = [UIScreen mainScreen].bounds.size;
    });
    return size;
}

@end
