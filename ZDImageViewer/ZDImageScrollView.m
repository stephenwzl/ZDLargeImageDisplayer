//
//  ZDImageScrollView.m
//  ZDImageViewer
//
//  Created by 王志龙 on 2017/7/11.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "ZDImageScrollView.h"
#import "ZDImageLocalCache.h"
#include <math.h>

#define BYTES_PER_MB (1024 * 1024.f)
#define BYTES_PER_PIXEL (32.f / 8)   ///32 bits per pixel for iOS device
#define PIXEL_PER_MB (BYTES_PER_MB / BYTES_PER_PIXEL)



static const CGFloat kDefaultTileBaseLength = 256.f;

static NSInteger firstLoadingCount = 0;
static NSInteger firstLoadingTotalCount = 0;
static BOOL isFirstLoading = NO;
static void(^globalFirstLoadinProgressCallBack)(CGFloat progress, BOOL);
static dispatch_semaphore_t lock;
static inline void setFirstLoadingCount(NSInteger count) {
  if (!isFirstLoading) {
    return;
  }
  dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
  firstLoadingCount = count;
  if (globalFirstLoadinProgressCallBack) {
    dispatch_async(dispatch_get_main_queue(), ^{
      globalFirstLoadinProgressCallBack((CGFloat)count / (CGFloat)firstLoadingTotalCount, count == firstLoadingTotalCount);
    });
  }
  if (count == firstLoadingTotalCount) {
    isFirstLoading = NO;
  }
  dispatch_semaphore_signal(lock);
}

static inline void setFirstLoadingTotalCount(NSInteger count) {
  dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
  firstLoadingTotalCount = count;
  dispatch_semaphore_signal(lock);
}



#pragma mark - MAIN IMPLEMENTATION
@interface ZDImageScrollView () <ZDImageDisplayerBitMapDelegate, UIScrollViewDelegate>

@property (nonatomic, readonly) UIImage *rawImage;
@property (nonatomic, strong) ZDImageDisplayer *imageDisplayer;

@end

@implementation ZDImageScrollView

- (instancetype)initWithLocalImageName:(NSString *)imageName viewFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      lock = dispatch_semaphore_create(1);
      isFirstLoading = YES;
    });
    NSString *path = [[NSBundle mainBundle] pathForResource:imageName ofType:@"jpg"];
    _rawImage = [[UIImage alloc] initWithContentsOfFile:path];
    CGFloat scale = [UIScreen mainScreen].scale;
    _rawImageSize = CGSizeMake(CGImageGetWidth(_rawImage.CGImage) / scale, CGImageGetHeight(_rawImage.CGImage) / scale);
    _imageDisplayer = [[ZDImageDisplayer alloc] initWithFrame:CGRectMake(0, 0, _rawImageSize.width, _rawImageSize.height)];
    _imageDisplayer.delegate = self;
    self.delegate = self;
    [self setContentSize:_rawImageSize];
    [self addSubview:_imageDisplayer];
    
    self.maximumZoomScale = 1.f;
    CGSize viewSize = self.bounds.size;
    self.minimumZoomScale = MIN(viewSize.width / _rawImageSize.width, viewSize.height / _rawImageSize.height);
    _imageDisplayer.numberOfZoomLevels = 3;
  }
  return self;
}

#pragma mark - UIScrollViewDelegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
  return self.imageDisplayer;
}

#pragma mark - ZDImageDisplayer delegate
- (UIImage *)imageDisplayer:(ZDImageDisplayer *)displayer
                imageForRow:(NSInteger)row
                     column:(NSInteger)column
                      scale:(CGFloat)scale {
  CGSize tileResolutionSize = [displayer rawResolutionSize];
  CGFloat xInSourceImage = column * tileResolutionSize.width / scale;
  CGFloat yInSourceImage = row * tileResolutionSize.height / scale;
  CGRect tileRectInSourceImageRect = CGRectMake(xInSourceImage,
                                                yInSourceImage,
                                                tileResolutionSize.width / scale,
                                                tileResolutionSize.height / scale);
  /// most iOS device are RGB color space
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef tileContext = CGBitmapContextCreate(NULL,
                                                   CGRectGetWidth(tileRectInSourceImageRect),
                                                   CGRectGetHeight(tileRectInSourceImageRect),
                                                   8, 0, colorSpace,
                                                   kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst);
  NSAssert(tileContext != NULL, @"can't create tile bitmap context");
  CGColorSpaceRelease(colorSpace);
  
  CGImageRef tileImageRef = CGImageCreateWithImageInRect(self.rawImage.CGImage, tileRectInSourceImageRect);
  NSAssert(tileImageRef != NULL, @"current tile range: %@", NSStringFromCGRect(tileRectInSourceImageRect));
  tileRectInSourceImageRect.origin = CGPointZero;
  CGContextDrawImage(tileContext, tileRectInSourceImageRect, tileImageRef);
  CGImageRelease(tileImageRef);
  tileImageRef = CGBitmapContextCreateImage(tileContext);
  UIImage *tileImage = [UIImage imageWithCGImage:tileImageRef scale:1.f orientation:UIImageOrientationUp];
  CGImageRelease(tileImageRef);
  CGContextRelease(tileContext);
  return tileImage;
}

+ (void)setFirstLoadingProgressCallBack:(void (^)(CGFloat, BOOL))firstLoadingProgressCallBack {
  globalFirstLoadinProgressCallBack = [firstLoadingProgressCallBack copy];
}

+ (void (^)(CGFloat, BOOL))firstLoadingProgressCallBack {
  return globalFirstLoadinProgressCallBack;
}

@end


@interface ZDTiledLayer: CATiledLayer

@end

@implementation ZDTiledLayer

+ (CFTimeInterval)fadeDuration {
  return 0.f;
}

@end

@implementation ZDImageDisplayer

+ (Class)layerClass {
  return [ZDTiledLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    CGSize scaledTileSize = CGSizeApplyAffineTransform(CGSizeMake(kDefaultTileBaseLength, kDefaultTileBaseLength), CGAffineTransformMakeScale(self.contentScaleFactor, self.contentScaleFactor));
    self.tiledLayer.tileSize = scaledTileSize;
    _rawResolutionSize = scaledTileSize;
    self.tiledLayer.levelsOfDetail = 1;
  }
  return self;
}

- (void)setNumberOfZoomLevels:(size_t)numberOfZoomLevels {
  _numberOfZoomLevels = numberOfZoomLevels;
  self.tiledLayer.levelsOfDetail = numberOfZoomLevels;
}

- (void)drawRect:(CGRect)rect {
  if (isFirstLoading && firstLoadingTotalCount == 0 && firstLoadingCount == 0) {
    NSInteger count = (NSInteger)round(CGRectGetWidth(self.bounds) / CGRectGetWidth(rect)) * (NSInteger)round(CGRectGetHeight(self.bounds) / CGRectGetHeight(rect));
    setFirstLoadingTotalCount(count);
  }
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat scale = CGContextGetCTM(ctx).a / self.tiledLayer.contentsScale;
  
  NSInteger col = (NSInteger)round((CGRectGetMinX(rect) * scale) / kDefaultTileBaseLength);
  NSInteger row = (NSInteger)round((CGRectGetMinY(rect) * scale) / kDefaultTileBaseLength);
  
  UIImage *tileImage = [self.delegate imageDisplayer:self imageForRow:row column:col scale:scale];
  [tileImage drawInRect:rect];
  setFirstLoadingCount(firstLoadingCount + 1);
}

#pragma mark - getter
- (ZDTiledLayer *)tiledLayer {
  return (ZDTiledLayer *)self.layer;
}

@end

