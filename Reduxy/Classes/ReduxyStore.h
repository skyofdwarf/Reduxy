//
//  ReduxyStore.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ReduxyTypes.h"

/**
 ReduxyStore
 */
@interface ReduxyStore : NSObject <ReduxyStore>

+ (instancetype)storeWithState:(ReduxyState)state
                       reducer:(ReduxyReducer)reducer
                       actions:(NSArray *)actions;

+ (instancetype)storeWithState:(ReduxyState)state
                       reducer:(ReduxyReducer)reducer
                   middlewares:(NSArray<ReduxyMiddleware> *)middlewares
                       actions:(NSArray *)actions;

- (instancetype)initWithState:(ReduxyState)state
                      reducer:(ReduxyReducer)reducer
                      actions:(NSArray *)actions;

- (instancetype)initWithState:(ReduxyState)state
                      reducer:(ReduxyReducer)reducer
                  middlewares:(NSArray<ReduxyMiddleware> *)middlewares
                      actions:(NSArray *)actions;
    
- (ReduxyState)getState;

- (id)dispatch:(ReduxyAction)action;
- (id)dispatch:(ReduxyActionType)type payload:(ReduxyActionPayload)payload;

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber;
- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber;
- (void)unsubscribeAll;

@end
