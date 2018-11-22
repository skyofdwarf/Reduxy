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
@property (copy, nonatomic) ReduxyReducer rootReducer;
@property (strong, nonatomic) ReduxySimpleRecorder *recorder;

@property (strong, nonatomic) ReduxyStore *store;
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
    self = [super init];
    if (self) {
        self.rootReducer = [self createRootReducer];
        self.recorder = [self createRecorderWithRootReducer:self.rootReducer];
        self.store = [self createMainStoreWithRootReducer:self.rootReducer recorder:self.recorder];
    }
    return self;
}

- (ReduxyReducer)createRootReducer {
    UINavigationController *nv = (UINavigationController *)ReduxyAppDelegate.shared.window.rootViewController;
    UIViewController *vc = nv.topViewController;
    
    // normal reducers
    ReduxyReducer breedsReducer = ReduxyKeyPathReducerForAction(ratype(breedlist.reload), @"breeds", @{});
    ReduxyReducer filterReducer = ReduxyKeyPathReducerForAction(ratype(breedlist.filtered), @"filter", @"");
    ReduxyReducer randomDogReducer = ReduxyKeyPathReducerForAction(ratype(randomdog.reload), @"randomdog", @"");
    ReduxyReducer indicatorReducer = ReduxyValueReducerForAction(ratype(indicator), @NO);
    
    // router reducers
    ReduxyReducerTransducer routerReducer = [ReduxyRouter.shared reducerWithInitialRoutables:@[ nv, vc ]
                                                                                    forPaths:@[ @"navigation", @"breedlist" ]];
    
    // root reducer
    return routerReducer(ReduxyPlayerReducer(^ReduxyState (ReduxyState state, ReduxyAction action) {
        return @{ @"fixed-menu": @[ @"Random dog" ], ///< fixed state
                  @"breeds": breedsReducer(state[@"breeds"], action),
                  @"filter": filterReducer(state[@"filter"], action),
                  @"randomdog": randomDogReducer(state[@"randomdog"], action),
                  @"indicator": indicatorReducer(state[@"indicator"], action),
                  };
    }));
}
    
- (ReduxySimpleRecorder *)createRecorderWithRootReducer:(ReduxyReducer)rootReducer {
    return [[ReduxySimpleRecorder alloc] initWithRootReducer:rootReducer
                                     ignorableActions:@[ ReduxyPlayerActionJump, ReduxyPlayerActionStep ]];
}

- (ReduxyStore *)createMainStoreWithRootReducer:(ReduxyReducer)rootReducer recorder:(id<ReduxyRecorder>)recorder {
    return [ReduxyStore storeWithState:rootReducer(nil, nil)
                               reducer:rootReducer
                           middlewares:@[ logger,
                                          ReduxyFunctionMiddleware,
                                          ReduxyRecorderMiddlewareWithRecorder(recorder),
                                          ReduxyPlayerMiddleware,
                                          mainQueue
                                          ]];
    
}


#pragma mark - proxy helpers

+ (ReduxyStore *)main {
    return Store.shared.store;
}

+ (ReduxySimpleRecorder *)recorder {
    return Store.shared.recorder;
}



@end
