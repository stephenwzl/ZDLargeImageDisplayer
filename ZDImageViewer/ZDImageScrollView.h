//
//  ZDImageScrollView.h
//  ZDImageViewer
//
//  Created by 王志龙 on 2017/7/11.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ZDTiledLayer, ZDImageDisplayer;
@protocol ZDImageDisplayerBitMapDelegate <NSObject>

@required
- (UIImage *)imageDisplayer:(ZDImageDisplayer *)displayer
                imageForRow:(NSInteger)row
                     column:(NSInteger)column
                      scale:(CGFloat)scale;

@end

@interface ZDImageScrollView : UIScrollView

@property (nonatomic, readonly) CGSize rawImageSize;
/**
 init with image name in main bundle
 
 @param imageName image name without type suffix
 @param frame the scrollview's frame
 @return instance of scroll view
 */
- (instancetype)initWithLocalImageName:(NSString *)imageName viewFrame:(CGRect)frame;

@end

@interface ZDImageDisplayer : UIView

@property (nonatomic, weak) id<ZDImageDisplayerBitMapDelegate> delegate;
@property (nonatomic, readonly) ZDTiledLayer *tiledLayer;
@property (nonatomic, assign) size_t numberOfZoomLevels;
@property (nonatomic, readonly) CGSize rawResolutionSize;

@end

NS_ASSUME_NONNULL_END
