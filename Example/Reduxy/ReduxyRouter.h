//
//  ReduxyRouter.h
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef BOOL(^RouteAction)(UIViewController *src, id context);

@interface ReduxyRouter : NSObject

+ (instancetype)shared;


- (void)add:(NSString *)path route:(RouteAction)route;
- (void)remove:(NSString *)path;
- (void)route:(NSString *)path;

@end
