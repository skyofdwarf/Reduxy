//
//  UIViewController+ReduxyRoutable.h
//  Reduxy_Example
//
//  Created by skyofdwarf on 2018. 12. 6..
//  Copyright © 2018년 skyofdwarf. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ReduxyRoutable.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (ReduxyRoutable) <ReduxyRoutable>

- (void)reduxyrouter_willMoveToParentViewController:(UIViewController *)parent;
- (void)reduxyrouter_didMoveToParentViewController:(UIViewController *)parent;

@end


NS_ASSUME_NONNULL_END
