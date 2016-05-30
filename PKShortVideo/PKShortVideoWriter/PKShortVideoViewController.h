//
//  PKShortVideoViewController.h
//  DevelopWriterDemo
//
//  Created by jiangxincai on 16/1/14.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PKShortVideoViewController : UIViewController

@property (nonatomic, assign) NSTimeInterval videoDurationTime;

- (instancetype)initWithOutputFilePath:(NSString *)outputFilePath outputSize:(CGSize)outputSize themeColor:(UIColor *)themeColor;

@end
