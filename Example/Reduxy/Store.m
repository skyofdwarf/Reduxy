//
//  Store.m
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "Store.h"

static ReduxyMiddleware logger = ReduxyMiddlewareCreateMacro(store, next, action, {
    LOG(@"logger mw> received action: %@", action.type);
    return next(action);
});

static ReduxyMiddleware mainQueue = ReduxyMiddlewareCreateMacro(store, next, action, {
    LOG(@"mainQueue mw> received action: %@", action.type);
    
    if ([NSThread isMainThread]) {
        LOG(@"mainQueue mw> in main-queue");
        return next(action);
    }
    else {
        LOG(@"mainQueue mw> not in main-queue, call next(acton) in async");
        dispatch_async(dispatch_get_main_queue(), ^{
            next(action);
        });
        return action;
    }
});



@interface Store ()
@end

@implementation Store

+ (Store *)shared {
    static dispatch_once_t onceToken;
    static Store *instance;
    
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    
    return instance;
}

+ (ReduxyReducer)createRootReducer {
    // normal reducers
    ReduxyReducer breedsReducer = ReduxyKeyPathReducerForAction(ratype(breedlist.reload), @"breeds", @{});
    ReduxyReducer filterReducer = ReduxyKeyPathReducerForAction(ratype(breedlist.filtered), @"filter", @"");
    ReduxyReducer indicatorReducer = ReduxyValueReducerForAction(ratype(indicator), @NO);
    
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        return @{ @"breeds": breedsReducer([state valueForKeyPath:@"breeds"], action),
                  @"filter": filterReducer([state valueForKeyPath:@"filter"], action),
                  @"indicator": indicatorReducer(state[@"indicator"], action),
                  };
    };
}

- (instancetype)init {
    ReduxyReducer rootReducer = [self.class createRootReducer];
    
    self = [super initWithState:rootReducer(nil, nil)
                        reducer:rootReducer
                    middlewares:@[ logger,
                                   ReduxyFunctionMiddleware,
                                   mainQueue
                                   ]];
    if (self) {
    }
    
    return self;
}

@end
