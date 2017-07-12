//
//  ZDImageLocalCache.h
//  ZDImageViewer
//
//  Created by stephenw on 2017/7/12.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZDImageLocalCache : NSObject

+ (instancetype)sharedCache;

@property (nonatomic, copy) NSString *localCachePath;

- (void)setImage:(UIImage *)image forKey:(NSString *)key;
- (UIImage *)getImageForKey:(NSString *)key;

@end
