//
//  AboutViewController.m
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "AboutViewController.h"
#import "ReduxyRouter.h"

#define LOG_HERE NSLog(@"%s", __PRETTY_FUNCTION__);

@interface AboutViewController ()

@end

@implementation AboutViewController

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
    
    NSLog(@"vcs: %@", ReduxyRouter.shared.vcs);
}


- (void)viewWillDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewDidDisappear:animated];
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    NSLog(@"AboutViewController> parent: %@", parent);
    
    [ReduxyRouter.shared viewController:self willMoveToParentViewController:parent];
}


@end
