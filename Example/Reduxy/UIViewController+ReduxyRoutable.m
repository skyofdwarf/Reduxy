//
//  UIViewController+ReduxyRoutable.m
//  Reduxy_Example
//
//  Created by skyofdwarf on 2018. 12. 6..
//  Copyright © 2018년 skyofdwarf. All rights reserved.
//

#import "UIViewController+ReduxyRoutable.h"
#import "ReduxyRouter.h"

@implementation UIViewController (ReduxyRoutable)

- (NSString *)path {
    return self.description;
}

- (UIViewController *)vc {
    return self;
}

- (void)reduxyrouter_willMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    
    if ([self conformsToProtocol:@protocol(ReduxyRoutable)]) {
        UIViewController<ReduxyRoutable> *routable = (UIViewController<ReduxyRoutable> *)self;
        [ReduxyRouter.shared viewController:routable willMoveToParentViewController:parent];
    }
}

- (void)reduxyrouter_didMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    
    if ([self conformsToProtocol:@protocol(ReduxyRoutable)]) {
        UIViewController<ReduxyRoutable> *routable = (UIViewController<ReduxyRoutable> *)self;
        [ReduxyRouter.shared viewController:routable didMoveToParentViewController:parent];
    }
}

@end
