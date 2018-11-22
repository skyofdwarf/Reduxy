//
//  Store.m
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "Store.h"

#import "ReduxySimpleRecorder.h"
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

- (instancetype)init {
    ReduxyReducer rootReducer = [self createRootReducer];
    
    self = [super initWithState:rootReducer(nil, nil)
                        reducer:rootReducer
                    middlewares:@[ logger,
                                   ReduxyFunctionMiddleware,
                                   ReduxyPlayerMiddleware,
                                   mainQueue
                                   ]];
    if (self) {
        self.recorder = [self createRecorderWithStore:self];
    }
    
    return self;
}

- (ReduxyReducer)createRootReducer {
    UINavigationController *nv = (UINavigationController *)ReduxyAppDelegate.shared.window.rootViewController;
    UIViewController *vc = nv.topViewController;
    
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
    
    // root reducer
    return routerReducer(ReduxyPlayerReducer(^ReduxyState (ReduxyState state, ReduxyAction action) {
        return @{ @"fixed-menu": @[ @"randomdog", @"localstore" ], ///< fixed state
                  @"breeds": breedsReducer(state[@"breeds"], action),
                  @"filter": filterReducer(state[@"filter"], action),
                  @"randomdog": randomdogReducer(state[@"randomdog"], action),
                  @"indicator": indicatorReducer(state[@"indicator"], action),
                  };
    }));
}
    
- (ReduxySimpleRecorder *)createRecorderWithStore:(id<ReduxyStore>)store {
    return [[ReduxySimpleRecorder alloc] initWithStore:store actionTypesToIgnore:@[ ReduxyPlayerActionJump,
                                                                                                              ReduxyPlayerActionStep ]];
}

- (ReduxyStore *)createMainStoreWithRootReducer:(ReduxyReducer)rootReducer {
    return [ReduxyStore storeWithState:rootReducer(nil, nil)
                               reducer:rootReducer
                           middlewares:@[ logger,
                                          ReduxyFunctionMiddleware,
                                          ReduxyPlayerMiddleware,
                                          mainQueue
                                          ]];
    
}



@end
