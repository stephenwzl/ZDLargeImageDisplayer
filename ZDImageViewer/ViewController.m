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

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  _imageScrollView = [[ZDImageScrollView alloc] initWithLocalImageName:@"zelda-map" viewFrame:[UIScreen mainScreen].bounds];
  [self.view addSubview:_imageScrollView];
}


@end
