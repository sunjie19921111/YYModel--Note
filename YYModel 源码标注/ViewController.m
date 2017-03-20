//
//  ViewController.m
//  YYModel 源码标注
//
//  Created by sxmaps on 2017/3/11.
//  Copyright © 2017年 sxmaps. All rights reserved.
//

#import "ViewController.h"
#import "testModel.h"
#import "NSObject+YYModel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"weibo_0.json" ofType:nil];
    NSData *data = [NSData dataWithContentsOfFile:path];
    testModel *model = [testModel modelWithJSON:data];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    [NSObject cancelPreviousPerformRequestsWithTarget:<#(nonnull id)#>]
}



@end
