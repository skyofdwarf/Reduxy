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

- (IBAction)popButtonDidClick:(id)sender {
    LOG(@"dispatch back in pop button");
    
    // explicit unroute
    [ReduxyRouter.shared unrouteFrom:self];
}


@end
