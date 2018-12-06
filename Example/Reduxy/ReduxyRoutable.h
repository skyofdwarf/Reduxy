//
//  ReduxyRoutable.h
//  Reduxy_Example
//
//  Created by skyofdwarf on 2018. 12. 6..
//  Copyright © 2018년 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ReduxyRoutable <NSObject>

@optional
- (UIViewController *)vc;
- (UIView *)view;
@end




NS_ASSUME_NONNULL_END
