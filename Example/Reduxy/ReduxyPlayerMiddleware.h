//
//  ReduxyPlayerMiddleware.h
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ReduxySimpleRecorder.h"
#import "ReduxyTypes.h"



FOUNDATION_EXTERN ReduxyActionType ReduxyPlayerActionJump;

FOUNDATION_EXTERN ReduxyMiddleware ReduxyPlayerMiddleware;

FOUNDATION_EXTERN ReduxyReducer (^ReduxyPlayerReducerWithRootReducer)(ReduxyReducer);


@protocol ReduxyPlayer <NSObject>
- (void)loadItems:(NSArray<id<ReduxyRecorderItem>> *)items dispatch:(ReduxyDispatch)dispatch;

- (NSInteger)length;

- (ReduxyAction)jump:(NSInteger)index;

- (ReduxyAction)prev;
- (ReduxyAction)next;

- (void)reset;

@end



