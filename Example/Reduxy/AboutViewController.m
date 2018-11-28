//
//  AboutViewController.m
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "AboutViewController.h"
#import "ReduxyRouter.h"
#import "ReduxySimplePlayer.h"


@interface AboutViewController ()
@end

@implementation AboutViewController

- (NSString *)path {
    return @"about";
}

+ (void)load {
    [self buildRoutes];
}

+ (void)buildRoutes {
    
    [ReduxyRouter.shared add:@"go to root" route:^id<ReduxyRoutable>(id<ReduxyRoutable> src, id context, RouteCompletion completion) {
        return nil;
    } unroute:^id<ReduxyRoutable>(id<ReduxyRoutable> src, id context, RouteCompletion completion) {
        [src.vc.navigationController popToRootViewControllerAnimated:YES];
        return src;
    }];
}


- (void)dealloc {
    LOG_HERE
}

- (void)viewDidLoad {
    LOG_HERE
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    LOG_HERE
    
    [super viewWillAppear:animated];
}


- (void)viewDidAppear:(BOOL)animated {
    LOG_HERE
    
    [super viewDidAppear:animated];
}


- (void)viewWillDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewDidDisappear:animated];
}

- (IBAction)nextButtonDidClick:(id)sender {
    [Store.shared.player next];
}

- (IBAction)popButtonDidClick:(id)sender {
    LOG(@"dispatch back in pop button");
    
    //[ReduxyRouter.shared unroutePath:@"about" context:nil];
    
    //[self.navigationController popToRootViewControllerAnimated:YES];
    
    [ReduxyRouter.shared unroutePath:@"go to root" from:self context:nil];
}


@end
