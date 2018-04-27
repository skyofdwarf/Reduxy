//
//  ReduxyForwardOnlyPlayer.h
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"
#import "ReduxyRecorderMiddleware.h"
#import "ReduxyStore.h"
#import "ReduxyPlayer.h"


@interface ReduxyForwardOnlyPlayer : NSObject <ReduxyPlayer>

+ (instancetype)shared;

- (void)loadItems:(NSArray<id<ReduxyRecorderItem>> *)actions dispatch:(ReduxyDispatch)dispatch;

- (BOOL)finished;
- (ReduxyAction)next;

@end
