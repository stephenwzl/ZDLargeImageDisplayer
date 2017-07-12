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

#pragma mark - MAIN IMPLEMENTATION
@interface ZDImageScrollView () <ZDImageDisplayerBitMapDelegate, UIScrollViewDelegate>

@property (nonatomic, readonly) UIImage *rawImage;
@property (nonatomic, strong) ZDImageDisplayer *imageDisplayer;

@end

@implementation ZDImageScrollView

- (instancetype)initWithLocalImageName:(NSString *)imageName viewFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
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
    _imageDisplayer.numberOfZoomLevels = 2;
    //initialize cache
    [[ZDImageLocalCache sharedCache] setLocalCachePath:imageName];
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
  NSString *cacheKey = [NSString stringWithFormat:@"row_%@_col_%@_scale_%@", @(row).stringValue, @(column).stringValue, @(scale).stringValue];
  UIImage *imageInCache = [[ZDImageLocalCache sharedCache] getImageForKey:cacheKey];
  if (imageInCache) {
    return imageInCache;
  }
  /// most iOS device are RGB color space
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  int bytePerRow = BYTES_PER_PIXEL * tileResolutionSize.width / scale;
  void *bitmapDataBuffer = malloc(bytePerRow * tileResolutionSize.height / scale);
  NSAssert(bitmapDataBuffer != NULL, @"can't allocate enough buffer space for bitmap create");
  CGContextRef tileContext = CGBitmapContextCreate(bitmapDataBuffer,
                                                   (tileResolutionSize.width / scale),
                                                   (tileResolutionSize.height / scale),
                                                   8, bytePerRow, colorSpace,
                                                   kCGImageAlphaPremultipliedLast);
  NSAssert(tileContext != NULL, @"can't create tile bitmap context");
  CGColorSpaceRelease(colorSpace);
  /// flip the coordinate
  CGContextTranslateCTM( tileContext, 0.0f, tileResolutionSize.height / scale );
  CGContextScaleCTM( tileContext, 1.0f, -1.0f );
  
  CGImageRef tileImageRef = CGImageCreateWithImageInRect(self.rawImage.CGImage, tileRectInSourceImageRect);
  NSAssert(tileImageRef != NULL, @"current tile range: %@", NSStringFromCGRect(tileRectInSourceImageRect));
  tileRectInSourceImageRect.origin = CGPointZero;
  CGContextDrawImage(tileContext, tileRectInSourceImageRect, tileImageRef);
  CGImageRelease(tileImageRef);
  tileImageRef = CGBitmapContextCreateImage(tileContext);
  UIImage *tileImage = [UIImage imageWithCGImage:tileImageRef scale:1.f orientation:UIImageOrientationDownMirrored];
  CGImageRelease(tileImageRef);
  CGContextRelease(tileContext);
  free(bitmapDataBuffer);
  //store to cache
  [[ZDImageLocalCache sharedCache] setImage:tileImage forKey:cacheKey];
  return tileImage;
}

@end


@interface ZDTiledLayer: CATiledLayer

@end

@implementation ZDTiledLayer

+ (CFTimeInterval)fadeDuration {
  return 0.01f;
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
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat scale = CGContextGetCTM(ctx).a / self.tiledLayer.contentsScale;
  
  NSInteger col = (NSInteger)((CGRectGetMinX(rect) * scale) / kDefaultTileBaseLength);
  NSInteger row = (NSInteger)((CGRectGetMinY(rect) * scale) / kDefaultTileBaseLength);
  
  UIImage *tileImage = [self.delegate imageDisplayer:self imageForRow:row column:col scale:scale];
  [tileImage drawInRect:rect];
}

#pragma mark - getter
- (ZDTiledLayer *)tiledLayer {
  return (ZDTiledLayer *)self.layer;
}

@end

