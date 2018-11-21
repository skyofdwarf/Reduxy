//
//  ReduxyStore.m
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#import "ReduxyStore.h"


#define LOG_HERE  NSLog(@"%s", __PRETTY_FUNCTION__);


@interface ReduxyStore ()
@property (strong, atomic) ReduxyState state;
@property (assign, atomic) BOOL isDispatching;

@property (copy, nonatomic) ReduxyReducer reducer;
@property (copy, nonatomic) ReduxyDispatch dispatchFuction;

@property (strong, nonatomic) NSHashTable<id<ReduxyStoreSubscriber>> *subscribers;
@end


@implementation ReduxyStore

- (void)dealloc {
    LOG_HERE
}

+ (instancetype)storeWithReducer:(ReduxyReducer)reducer {
    return [[ReduxyStore alloc] initWithReducer:reducer];
}

+ (instancetype)storeWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer {
    return [ReduxyStore storeWithState:state reducer:reducer middlewares:nil];
}

+ (instancetype)storeWithReducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares {
    return [[ReduxyStore alloc] initWithReducer:reducer middlewares:middlewares];
}

+ (instancetype)storeWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares {
    return [[ReduxyStore alloc] initWithState:state reducer:reducer middlewares:middlewares];
}

- (instancetype)initWithReducer:(ReduxyReducer)reducer {
    return [self initWithState:@{} reducer:reducer];
}

- (instancetype)initWithReducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares {
    return [self initWithState:@{} reducer:reducer middlewares:middlewares];
}

- (instancetype)initWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer {
    return [self initWithState:state reducer:reducer middlewares:nil];
}

- (instancetype)initWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares {
    self = [super init];
    if (self) {
        self.subscribers = [NSHashTable weakObjectsHashTable];
        
        self.state = [state copy];
        self.reducer = reducer;
        
        self.dispatchFuction = [self buildDispatchWithMiddlewares:middlewares];
    }
    return self;
}

#pragma mark - private

- (ReduxyDispatch)buildDispatchWithMiddlewares:(NSArray<ReduxyMiddleware> *)middlewares {
    typeof(self) __weak wself = self;
    ReduxyDispatch defaultDispatch = ^ReduxyAction (ReduxyAction action) {
        typeof(self) __strong sself = wself;
        if (sself) {
            if (sself.isDispatching) {
                @throw [NSError errorWithDomain:ReduxyErrorDomain code:ReduxyErrorMultipleDispatching userInfo:nil];
                return action;
            }
            
            sself.isDispatching = YES;
            {
                sself.state = sself.reducer(sself.state, action);
            }
            sself.isDispatching = NO;
            
            [sself publishState:sself.state action:action];
        }
        
        return action;
    };
    
    NSArray<ReduxyMiddleware> *revereMiddlewares = [[middlewares reverseObjectEnumerator] allObjects];
    ReduxyDispatch dispatch = defaultDispatch;

    for (ReduxyMiddleware mw in revereMiddlewares) {
        dispatch = mw(self)(dispatch);
    }
    
    return dispatch;
}

- (void)publishState:(ReduxyState)state action:(ReduxyAction)action {
    for (id<ReduxyStoreSubscriber> subscriber in self.subscribers) {
        [self publishState:state to:subscriber action:action];
    }
}

- (void)publishState:(ReduxyState)state to:(id<ReduxyStoreSubscriber>)subscriber action:(ReduxyAction)action {
    [subscriber reduxyStore:self didChangeState:state byAction:action];
}

#pragma mark - public

- (ReduxyState)getState {
    return [self.state copy];
}

- (id)dispatch:(ReduxyAction)action {
    if (NSThread.isMainThread) {
        return self.dispatchFuction(action);
    }
    else {
        ReduxyDispatch dispatch = self.dispatchFuction;
        __block id result = nil;
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            result = dispatch(action);
        });
        
        return result;
    }
}

- (id)dispatch:(ReduxyActionType)type payload:(id)payload {
    NSDictionary *action = (payload?
                            @{ ReduxyActionTypeKey: type, ReduxyActionPayloadKey: payload }:
                            @{ ReduxyActionTypeKey: type });
    
    return [self dispatch:action];
}

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber {
    if (![self.subscribers containsObject:subscriber]) {
        [self.subscribers addObject:subscriber];
        
//        [self publishState:self.state to:subscriber action:ReduxyActionStoreSubscription];
    }
}

- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber {
    [self.subscribers removeObject:subscriber];
}

- (void)unsubscribeAll {
    [self.subscribers removeAllObjects];
}

@end

