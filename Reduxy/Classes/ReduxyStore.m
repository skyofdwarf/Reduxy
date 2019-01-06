//
//  ReduxyStore.m
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#import "ReduxyStore.h"
#import "ReduxyActionManager.h"
#import "ReduxyFunctionAction.h"
#import "ReduxyAsyncAction.h"



@interface ReduxyStore ()
@property (strong, atomic) ReduxyState state;

@property (copy, nonatomic) ReduxyReducer reducer;
@property (copy, nonatomic) ReduxyDispatch dispatchFuction;

@property (strong, nonatomic) NSHashTable<id<ReduxyStoreSubscriber>> *subscribers;
@property (strong, nonatomic) ReduxyActionManager *actionManager;

@end


@implementation ReduxyStore

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self unsubscribeAll];
}

+ (instancetype)storeWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer actions:(NSArray *)actions {
    return [ReduxyStore storeWithState:state reducer:reducer middlewares:@[] actions:actions];
}

+ (instancetype)storeWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares actions:(NSArray *)actions {
    return [[ReduxyStore alloc] initWithState:state reducer:reducer middlewares:middlewares actions:@[]];
}

- (instancetype)initWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer actions:(NSArray *)actions {
    return [self initWithState:state reducer:reducer middlewares:@[] actions:actions];
}

- (instancetype)initWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares actions:(NSArray *)actions {
    self = [super init];
    if (self) {
        self.subscribers = [NSHashTable weakObjectsHashTable];
        
        self.actionManager = [[ReduxyActionManager alloc] initWithActions:[actions arrayByAddingObjectsFromArray:@[ ratype(ReduxyFunctionAction),
                                                                                                                    ratype(ReduxyAsyncAction) ]]];
        
        self.state = [state copy];
        self.reducer = reducer;
        
        self.dispatchFuction = [self buildDispatchWithMiddlewares:middlewares];
    }
    return self;
}

#pragma mark - private

- (ReduxyAction)reduceWithAction:(ReduxyAction)action {
    self.state = self.reducer(self.state, action);
    
    [self publishState:self.state action:action];
    
    return action;
}


- (ReduxyDispatch)buildDispatchWithMiddlewares:(NSArray<ReduxyMiddleware> *)middlewares {
   typedef ReduxyDispatch (^ReduxyDefaulDispatch)(ReduxyStore *store);
    
    ReduxyDefaulDispatch defaultDispatch = ^ReduxyDispatch (ReduxyStore *store) {
        return ^ReduxyAction (ReduxyAction action) {
            return [store reduceWithAction:action];
        };
        
    };
    
    NSArray<ReduxyMiddleware> *revereMiddlewares = [[middlewares reverseObjectEnumerator] allObjects];
    ReduxyDispatch dispatch = defaultDispatch(self);

    for (ReduxyMiddleware mw in revereMiddlewares) {
        dispatch = mw(self)(dispatch);
    }
    
    return dispatch;
}

- (void)publishState:(ReduxyState)state action:(ReduxyAction)action {
    NSArray<id<ReduxyStoreSubscriber>> *subs = self.subscribers.allObjects;
    
    for (id<ReduxyStoreSubscriber> subscriber in subs) {
        [self publishState:state to:subscriber action:action];
    }
}

- (void)publishState:(ReduxyState)state to:(id<ReduxyStoreSubscriber>)subscriber action:(ReduxyAction)action {
    [subscriber store:self didChangeState:state byAction:action];
}

#pragma mark - public

- (ReduxyState)getState {
    return [self.state copy];
}

- (id)dispatch:(ReduxyAction)action {
    return self.dispatchFuction(action);
}

- (id)dispatch:(ReduxyActionType)type payload:(ReduxyActionPayload)payload {
    NSDictionary *action = (payload?
                            @{ ReduxyActionTypeKey: type, ReduxyActionPayloadKey: payload }:
                            @{ ReduxyActionTypeKey: type });
    
    return [self dispatch:action];
}

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber {
    if (![self.subscribers containsObject:subscriber]) {
        [self.subscribers addObject:subscriber];
    }
}

- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber {
    [self.subscribers removeObject:subscriber];
}

- (void)unsubscribeAll {
    [self.subscribers removeAllObjects];
}

@end

