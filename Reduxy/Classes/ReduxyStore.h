//
//  ReduxyStore.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ReduxyStoreDelegate.h"
#import "ReduxyTypes.h"

/*! Reduxy(Redux[Obj]C) is a implementation of redux with ObjC.
 */

/// reduxy store
@interface ReduxyStore : NSObject

+ (instancetype)storeWithReducer:(ReduxyReducer)reducer;

+ (instancetype)storeWithState:(ReduxyState)state
                       reducer:(ReduxyReducer)reducer;

+ (instancetype)storeWithState:(ReduxyState)state
                       reducer:(ReduxyReducer)reducer
                   middlewares:(NSArray<ReduxyMiddleware> *)middlewares;

- (instancetype)initWithReducer:(ReduxyReducer)reducer;
- (instancetype)initWithState:(ReduxyState)state

                      reducer:(ReduxyReducer)reducer;

- (instancetype)initWithState:(ReduxyState)state
                      reducer:(ReduxyReducer)reducer
                  middlewares:(NSArray<ReduxyMiddleware> *)middlewares;

    
- (ReduxyState)getState;

- (ReduxyAction)dispatch:(ReduxyAction)action;

- (void)subscribe:(id<ReduxyStoreDelegate>)subscriber;
- (void)unsubscribe:(id<ReduxyStoreDelegate>)subscriber;

@end
