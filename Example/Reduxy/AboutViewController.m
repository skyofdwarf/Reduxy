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
<
ReduxyRoutable
>

@end

@implementation AboutViewController

+ (NSString *)path {
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
    
    LOG(@"vcs: %@", ReduxyRouter.shared.vcs);
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
    [ReduxySimplePlayer.shared next];
}

- (IBAction)popButtonDidClick:(id)sender {
    LOG(@"dispatch back in pop button");
    
    [ReduxyRouter.shared dispatchUnroute:@{ @"path": @"about" }];
}


@end
