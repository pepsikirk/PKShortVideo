//
//  PKColorConversion.h
//  DevelopPlayerDemo
//
//  Created by jiangxincai on 16/1/11.
//  Copyright © 2016年 pepsikirk. All rights reserved.
//

#ifndef PKColorConversion_h
#define PKColorConversion_h

#import "GPUImageContext.h"

extern GLfloat *kColorConversion601;
extern GLfloat *kColorConversion601FullRange;
extern GLfloat *kColorConversion709;
extern NSString *const kGPUImageVertexShaderString;
extern NSString *const kGPUImageYUVFullRangeConversionForLAFragmentShaderString;
extern NSString *const kGPUImagePassthroughFragmentShaderString;

#endif /* PKColorConversion_h */
