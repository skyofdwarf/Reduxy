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

@property (strong, nonatomic) NSMutableSet<id<ReduxyStoreSubscriber>> *subscribers;
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

+ (instancetype)storeWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares {
    return [[ReduxyStore alloc] initWithState:state reducer:reducer middlewares:middlewares];
}

- (instancetype)initWithReducer:(ReduxyReducer)reducer {
    return [self initWithState:@{} reducer:reducer];
}

- (instancetype)initWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer {
    return [self initWithState:state reducer:reducer middlewares:nil];
}

- (instancetype)initWithState:(ReduxyState)state reducer:(ReduxyReducer)reducer middlewares:(NSArray<ReduxyMiddleware> *)middlewares {
    self = [super init];
    if (self) {
        self.subscribers = [NSMutableSet set];
        
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
            
            NSLog(@"in default dispatch");
            NSLog(@"\tcall reducer");
            
            sself.isDispatching = YES;
            {
                sself.state = sself.reducer(sself.state, action);
            }
            sself.isDispatching = NO;
            
            NSLog(@"\twill publish new state");
            [sself publish:sself.state];
            NSLog(@"\tdid publish new state");
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

- (void)publish:(ReduxyState)state {
    for (id<ReduxyStoreSubscriber> subscriber in self.subscribers) {
        [self publish:state to:subscriber];
    }
}

- (void)publish:(ReduxyState)state to:(id<ReduxyStoreSubscriber>)subscriber {
    [subscriber reduxyStore:self stateDidChange:state];
}

#pragma mark - public

- (ReduxyState)getState {
    return [self.state copy];
}

- (ReduxyAction)dispatch:(ReduxyAction)action {
    return self.dispatchFuction(action);
}

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber {
    if (![self.subscribers containsObject:subscriber]) {
        [self.subscribers addObject:subscriber];
        
        [self publish:self.state to:subscriber];
    }
}

- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber {
    [self.subscribers removeObject:subscriber];
}

@end

