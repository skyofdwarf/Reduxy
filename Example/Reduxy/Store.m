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
    LOG(@"logger> received action: %@", action);
    return next(action);
});



@interface Store ()
@property (copy, nonatomic) ReduxyReducer rootReducer;
@property (strong, nonatomic) ReduxySimpleRecorder *recorder;

@property (strong, nonatomic) ReduxyStore *store;
@end


@implementation Store

+ (Store *)shared {
    static dispatch_once_t onceToken;
    static Store *store;
    
    dispatch_once(&onceToken, ^{
        store = [self new];
    });
    
    return store;
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
    ReduxyReducer breedsReducer = ReduxyKeyValueReducerForAction(raction_x(breedlist.fetched), @"breeds", @{});
    ReduxyReducer filterReducer = ReduxyKeyValueReducerForAction(raction_x(breedlist.filtered), @"filter", @"");
    ReduxyReducer randomDogReducer = ReduxyKeyValueReducerForAction(raction_x(randomdog.fetched), @"randomdog", @"");
    
    // router reducers
    ReduxyReducer routerReducer = [ReduxyRouter.shared reducerWithInitialViewControllers:@[ nv, vc ]
                                                                                forPaths:@[ @"navigation", @"list" ]];
    
    // root reducer
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        return @{ ReduxyRouterStateKey: routerReducer(state[ReduxyRouterStateKey], action),
                  @"fixed-menu": @[ @"Random dog" ], ///< fixed state
                  @"breeds": breedsReducer(state[@"breeds"], action),
                  @"filter": filterReducer(state[@"filter"], action),
                  @"randomdog": randomDogReducer(state[@"randomdog"], action),
                  };
    };
}
    
- (ReduxySimpleRecorder *)createRecorderWithRootReducer:(ReduxyReducer)rootReducer {
    return [[ReduxySimpleRecorder alloc] initWithRootReducer:rootReducer
                                     ignorableActions:@[ ReduxyPlayerActionJump ]];
}

- (ReduxyStore *)createMainStoreWithRootReducer:(ReduxyReducer)rootReducer recorder:(id<ReduxyRecorder>)recorder {
    return [ReduxyStore storeWithState:rootReducer(nil, nil)
                               reducer:rootReducer
                           middlewares:@[ logger,
                                          ReduxyRecorderMiddlewareWithRecorder(recorder),
                                          ReduxyPlayerMiddleware,
                                          ReduxyFunctionMiddleware,
                                          ReduxyRouter.shared.middleware
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
