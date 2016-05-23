//
//  PKUtiltiies.h
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/17.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define kScreenSize [PKUtiltiies screenSize]
#define kScreenWidth [PKUtiltiies screenSize].width
#define kScreenHeight [PKUtiltiies screenSize].height

@interface PKUtiltiies : NSObject

+ (CGSize)screenSize;

@end
