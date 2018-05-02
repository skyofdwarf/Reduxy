//
//  ReduxySimplePlayer.h
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"
#import "ReduxyPlayerMiddleware.h"

@interface ReduxySimplePlayer : NSObject <ReduxyPlayer>
@property (assign, nonatomic, readonly) NSInteger position;

+ (instancetype)shared;

- (void)loadItems:(NSArray<id<ReduxyRecorderItem>> *)items dispatch:(ReduxyDispatch)dispatch;

- (BOOL)finished;

- (ReduxyAction)prev;
- (ReduxyAction)next;

@end
