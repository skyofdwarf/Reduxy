//
//  Store.m
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "Store.h"

#import "ReduxyRouter.h"
#import "ReduxySimplePlayer.h"
#import "ReduxyFunctionMiddleware.h"
#import "Actions.h"



#pragma mark - middlewares

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
@property (strong, nonatomic) ReduxySimpleRecorder *recorder;
@property (strong, nonatomic) ReduxySimplePlayer *player;
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
    UINavigationController *nv = (UINavigationController *)ReduxyAppDelegate.shared.window.rootViewController;
    id<ReduxyRoutable> vc = (id<ReduxyRoutable>)nv.topViewController;
    
    // normal reducers
    ReduxyReducer breedsReducer = ReduxyKeyPathReducerForAction(ratype(breedlist.reload), @"breeds", @{});
    ReduxyReducer filterReducer = ReduxyKeyPathReducerForAction(ratype(breedlist.filtered), @"filter", @"");
    ReduxyReducer indicatorReducer = ReduxyValueReducerForAction(ratype(indicator), @NO);
    
    ReduxyReducer randomdogReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:ratype(randomdog.reload)]) {
            UIImage *image = action.payload[@"image"];
            return (image? @{ @"image": image }: @{});
        }
        else {
            return (state? state: @{});
        }
    };
    
    // router reducers
    ReduxyReducerTransducer routerReducer = [ReduxyRouter.shared reducerWithInitialRoutables:@[ nv, vc ]
                                                                                    forPaths:@[ @"navigation", @"breedlist" ]];
    
    ReduxyReducer rootReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
        return @{ @"fixed-menu": @[ @"randomdog", @"localstore" ], ///< fixed state
                  @"breeds": breedsReducer(state[@"breeds"], action),
                  @"filter": filterReducer(state[@"filter"], action),
                  @"randomdog": randomdogReducer(state[@"randomdog"], action),
                  @"indicator": indicatorReducer(state[@"indicator"], action),
                  };
    };
    
    // root reducer
    //return routerReducer(ReduxySimplePlayer.reducer(rootReducer));
    return ReduxySimplePlayer.reducer(rootReducer);
}

- (instancetype)init {
    ReduxyReducer rootReducer = [self.class createRootReducer];
    
    self = [super initWithState:rootReducer(nil, nil)
                        reducer:rootReducer
                    middlewares:@[ logger,
                                   ReduxyFunctionMiddleware,
                                   ReduxySimplePlayer.middleware,
                                   mainQueue
                                   ]];
    if (self) {
        self.recorder = [[ReduxySimpleRecorder alloc] initWithStore:self
                                                actionTypesToIgnore:@[ ReduxyPlayerActionJump,
                                                                       ReduxyPlayerActionStep ]];
        self.player = [ReduxySimplePlayer new];
    }
    
    return self;
}

@end
