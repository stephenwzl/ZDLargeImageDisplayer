//
//  ViewController.m
//  ZDImageViewer
//
//  Created by 王志龙 on 2017/7/11.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "ViewController.h"
#import "ZDImageScrollView.h"

@interface ViewController ()

@property (nonatomic, strong) ZDImageScrollView *imageScrollView;
@property (weak, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  _imageScrollView = [[ZDImageScrollView alloc] initWithLocalImageName:@"zelda-map" viewFrame:[UIScreen mainScreen].bounds];
  [self.view addSubview:_imageScrollView];
  [self.view bringSubviewToFront:self.loadingView];
  __weak typeof(self) weakSelf = self;
  [ZDImageScrollView setFirstLoadingProgressCallBack:^ (CGFloat progress, BOOL done){
    weakSelf.progressView.progress = progress;
    if (done) {
      weakSelf.loadingView.hidden = YES;
    }
  }];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [_imageScrollView setZoomScale:_imageScrollView.minimumZoomScale animated:NO];
}


@end
