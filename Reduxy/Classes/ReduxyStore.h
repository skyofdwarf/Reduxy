//
//  ReduxyStore.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ReduxyTypes.h"




/*
 TODO: add -[subscriber:selector:]
 */




/*! Reduxy(Redux[Obj]C) is a implementation of redux with ObjC.
 */

/// reduxy store
@interface ReduxyStore : NSObject <ReduxyStore>

+ (instancetype)storeWithReducer:(ReduxyReducer)reducer;

+ (instancetype)storeWithReducer:(ReduxyReducer)reducer
                     middlewares:(NSArray<ReduxyMiddleware> *)middlewares;
    
+ (instancetype)storeWithState:(ReduxyState)state
                       reducer:(ReduxyReducer)reducer;

+ (instancetype)storeWithState:(ReduxyState)state
                       reducer:(ReduxyReducer)reducer
                   middlewares:(NSArray<ReduxyMiddleware> *)middlewares;

- (instancetype)initWithReducer:(ReduxyReducer)reducer;

- (instancetype)initWithReducer:(ReduxyReducer)reducer
                    middlewares:(NSArray<ReduxyMiddleware> *)middlewares;

- (instancetype)initWithState:(ReduxyState)state
                      reducer:(ReduxyReducer)reducer;

- (instancetype)initWithState:(ReduxyState)state
                      reducer:(ReduxyReducer)reducer
                  middlewares:(NSArray<ReduxyMiddleware> *)middlewares;

    
- (ReduxyState)getState;

- (id)dispatch:(ReduxyAction)action;
- (id)dispatch:(ReduxyActionType)type data:(id)data;

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber;
- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber;
- (void)unsubscribeAll;

@end
