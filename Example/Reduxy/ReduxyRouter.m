//
//  ReduxyRouter.m
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxyRouter.h"
#import "ReduxyMemoizer.h"
#import "ReduxyStore.h"

static selector_block routesSelector = ^NSArray<NSDictionary *> * _Nonnull (ReduxyState state) {
    return state[ReduxyRouter.stateKey];
};

static selector_block topRouteSelector = ^NSString * _Nullable (ReduxyState state) {
    NSArray<NSString *> *routes = routesSelector(state);
    return [routes lastObject];
};


@implementation UIViewController (ReduxyRoutable)

+ (NSString *)path {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Invalid call `+path` to UIViewController not conformed ReduxyRoutable"
                                 userInfo:nil];
}

- (UIViewController *)vc {
    return self;
}

/**
 overrides default implementation to catch system based view transition like navigation default back button and pop gesture.
 
 @note must be called if you overrided in subsclass of UIViewController.
 */
- (void)reduxyrouter_willMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    
    if ([self conformsToProtocol:@protocol(ReduxyRoutable)]) {
        UIViewController<ReduxyRoutable> *routable = (UIViewController<ReduxyRoutable> *)self;
        [ReduxyRouter.shared viewController:routable willMoveToParentViewController:parent];
    }
}

- (void)reduxyrouter_didMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    
    if ([self conformsToProtocol:@protocol(ReduxyRoutable)]) {
        UIViewController<ReduxyRoutable> *routable = (UIViewController<ReduxyRoutable> *)self;
        [ReduxyRouter.shared viewController:routable didMoveToParentViewController:parent];
    }
}

@end


#pragma mark - ReduxyRouter


@interface ReduxyRouter () <ReduxyStoreSubscriber>
@property (strong, nonatomic) id<ReduxyStore> store;

@property (strong, nonatomic) NSMutableDictionary<NSString */*path*/, RouteAction> *routes;
@property (strong, nonatomic) NSMutableDictionary<NSString */*path*/, RouteAction> *unroutes;
@property (strong, nonatomic) NSMutableArray<NSDictionary *> *routables;

@property (copy, nonatomic) NSDictionary *routingInfo;
@property (copy, nonatomic) NSDictionary *unroutingInfo;

@end

@implementation ReduxyRouter

static NSString * const _stateKey = @"reduxy.routes";

+ (NSString *)stateKey {
    return _stateKey;
}

+ (void)load {
    raction_add(router.route);
    raction_add(router.unroute);
    
    raction_add(router.route.by-state);
    raction_add(router.unroute.by-state);
    
    [self swizzle];
}

+ (void)swizzle {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method willMoveToParentViewController = class_getInstanceMethod(UIViewController.self, @selector(willMoveToParentViewController:));
        Method reduxyrouter_willMoveToParentViewController = class_getInstanceMethod(UIViewController.self, @selector(reduxyrouter_willMoveToParentViewController:));
        
        if (willMoveToParentViewController && reduxyrouter_willMoveToParentViewController) {
            method_exchangeImplementations(willMoveToParentViewController, reduxyrouter_willMoveToParentViewController);
        }
        
        Method didMoveToParentViewController = class_getInstanceMethod(UIViewController.self, @selector(didMoveToParentViewController:));
        Method reduxyrouter_didMoveToParentViewController = class_getInstanceMethod(UIViewController.self, @selector(reduxyrouter_didMoveToParentViewController:));
        
        if (didMoveToParentViewController && reduxyrouter_didMoveToParentViewController) {
            method_exchangeImplementations(didMoveToParentViewController, reduxyrouter_didMoveToParentViewController);
        }
    });
}

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static ReduxyRouter *instance;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.routes = @{}.mutableCopy;
        self.unroutes = @{}.mutableCopy;
        self.routables = [NSMutableArray array];
        
        self.routesAutoway = YES;
        self.routesByAction = NO;
    }
    return self;
}

#pragma mark - store

- (void)attachStore:(id<ReduxyStore>)store {
    if (self.store) {
        [self.store unsubscribe:self];
    }
    
    self.store = store;
    [store subscribe:self];
}

#pragma mark - routing

- (void)add:(NSString *)path route:(RouteAction)route unroute:(RouteAction)unroute {
    self.routes[path] = route;
    self.unroutes[path] = unroute;
}

- (void)remove:(NSString *)path {
    self.routes[path] = nil;
    self.unroutes[path] = nil;
}

- (BOOL)route:(NSString *)path source:(id<ReduxyRoutable>)routable context:(id)context {
    RouteAction route = self.routes[path];
    if (route) {
        [self willRouteForPath:path from:routable];
        
        void (^completion)(void) = context[@"completion"];
        
        __weak typeof(self) wself = self;
        route(routable, context, ^(id<ReduxyRoutable> dest) {
            [wself didRoute:dest];
            
            if (completion) {
                completion();
            }
        });
        return YES;
    }
    
    return NO;
}

- (BOOL)unroute:(NSString *)path source:(id<ReduxyRoutable>)routable context:(id)context {
    if (!routable) {
        return NO;
    }
    
    RouteAction unroute = self.unroutes[path];
    if (unroute) {
        [self willUnrouteForPath:path from:routable];
        
        void (^completion)(void) = context[@"completion"];
        
        // do manual unroute
        __weak typeof(self) wself = self;
        unroute(routable, context, ^(id<ReduxyRoutable> dest) {
            [wself didUnroute:dest];
            
            if (completion) {
                completion();
            }
        });
        
        return YES;
    }
    
    return NO;
}

#pragma mark - redux

+ (ReduxyMiddleware)middleware {
    
    return ReduxyMiddlewareCreateMacro(store, next, action, {
        LOG(@"router mw> received action: %@", action.type);
        
        if ([action is:ratype(router.route)]) {
            LOG(@"router mw> route action: %@", action.payload[@"path"]);
            
            [ReduxyRouter.shared route:action state:[store getState]];
        }
        else if ([action is:ratype(router.unroute)]) {
            LOG(@"router mw> unroute action: %@", action.payload[@"path"]);
            
            [ReduxyRouter.shared unroute:action state:[store getState]];
        }
        
        return next(action);
    });
}


- (ReduxyReducerTransducer)reducer {
    return [self reducerWithInitialRoutables:@[] forPaths:@[]];
}

- (ReduxyReducerTransducer)reducerWithInitialRoutables:(NSArray<id<ReduxyRoutable>> *)vcs forPaths:(NSArray<NSString *> *)paths {
    // builds root routing state
    NSMutableArray *initialState = @[].mutableCopy;
    for (NSInteger index = 0; index < paths.count; ++index) {
        NSString *path = paths[index];
        id<ReduxyRoutable> routable = vcs[index];
        
        [self pushRoutable:routable path:path];
        
        [initialState addObject:@{ @"path": path }];
    }
    
    NSArray *defaultState = initialState.copy;
    
    // returns a reducer for route state
    return ^ReduxyReducer (ReduxyReducer next) {
        return ^ReduxyState (ReduxyState state, ReduxyAction action) {
            ReduxyState nextState = next(state, action);
            
            NSMutableDictionary *mstate = [NSMutableDictionary dictionaryWithDictionary:nextState];
            NSArray *routes = state[ReduxyRouter.stateKey] ?: defaultState;
            
            if ([action is:ratype(router.route)]) {
                LOG(@"route reducer> route: %@, to: %@", action.payload, routes);
                
                NSMutableArray *mroutes = [NSMutableArray arrayWithArray:routes];
                
                [mroutes addObject:action.payload];
                [mstate setObject:mroutes.copy forKey:ReduxyRouter.stateKey];
                
                return [mstate copy];
            }
            else if ([action is:ratype(router.unroute)]) {
                LOG(@"route reducer> unroute: %@, from: %@", action.payload, routes);
#if 1 // multi-depth
                NSMutableArray *mroutes = [NSMutableArray arrayWithArray:routes];
                NSString *pathToPop = action.payload[@"path"];
                
                NSUInteger index = [routes indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    return [obj[@"path"] isEqualToString:pathToPop];
                }];
                
                if (index == NSNotFound) {
                    LOG(@"route reducer> not found the path in stack: %@", pathToPop);
                    
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                                   reason:[NSString stringWithFormat:@"Not found a path to pop in stack: %@", pathToPop]
                                                 userInfo:state];
                }
                else {
                    [mroutes removeObjectsInRange:NSMakeRange(index, mroutes.count - index)];
                }
                
                [mstate setObject:mroutes.copy forKey:ReduxyRouter.stateKey];
                
                return [mstate copy];
#else // one depth
                NSMutableArray *mroutes = [NSMutableArray arrayWithArray:routes];
                
                NSString *pathToPop = action.payload[@"path"];
                
                NSDictionary *topPathInfo = routes.lastObject;
                NSString *topPath = topPathInfo[@"path"];
                
                if ([topPath isEqualToString:pathToPop]) {
                    LOG(@"route reducer> pop the path: %@", pathToPop);
                    [mroutes removeLastObject];
                }
                else {
                    LOG(@"route reducer> not found the path on top: %@", pathToPop);
                    
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                                   reason:[NSString stringWithFormat:@"Not found a path to pop on top: %@", pathToPop]
                                                 userInfo:state];
                }
                
                [mstate setObject:mroutes.copy forKey:ReduxyRouter.stateKey];
                
                return [mstate copy];
#endif
            }
            else {
                [mstate setObject:routes forKey:ReduxyRouter.stateKey];
                return [mstate copy];
            }
        };
    };
}


#pragma mark - private

- (BOOL)route:(ReduxyAction)action state:(ReduxyState)state  {
    NSString *path  = action.payload[@"path"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    if (self.routesByAction) {
        NSString *way  = action.payload[@"way"];
        
        if (self.routesAutoway || !way) {
            id<ReduxyRoutable> routable = [self topRoutable];
            return [self route:path source:routable context:action.payload];
        }
        
        BOOL autorouting = (way != nil);
        return autorouting;
    }
    else {
        id<ReduxyRoutable> routable = [self topRoutable];
        return [self route:path source:routable context:action.payload];
    }
}

- (BOOL)unroute:(ReduxyAction)action state:(ReduxyState)state  {
    NSString *path  = action.payload[@"path"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    if (self.routesByAction) {
        NSString *way  = action.payload[@"way"];
        
        if (self.routesAutoway || !way) {
            id<ReduxyRoutable> routable = [self topRoutable];
            return [self unroute:path source:routable context:action.payload];
        }
        
        BOOL autorouting = (way != nil);
        return autorouting;
    }
    else {
        id<ReduxyRoutable> routable = [self topRoutable];
        return [self unroute:path source:routable context:action.payload];
    }
}

- (id<ReduxyRoutable>)topRoutable {
    NSDictionary *routableInfo = self.routables.lastObject;
    return routableInfo[@"routable"];
}


- (void)pushRoutable:(id<ReduxyRoutable>)routable path:(NSString *)path {
    [self.routables addObject:@{ @"path": path,
                                 @"routable": routable,
                                 @"hash": @(routable.hash) }];
}

- (void)popRoutable {
    [self.routables removeLastObject];
}

- (BOOL)popRoutablesToRoutable:(id<ReduxyRoutable>)routable {
    NSUInteger index = NSNotFound;
    
    for (NSDictionary *info in self.routables) {
        NSNumber *hash = info[@"hash"];
        NSString *path = info[@"path"];
        
        if ([hash isEqualToNumber:@(routable.hash)] &&
            [path isEqualToString:[routable.class path]])
        {
            index = [self.routables indexOfObject:info];
        }
    }

    if (index == NSNotFound) {
        return NO;
    }
    else {
        [self.routables removeObjectsInRange:NSMakeRange(index, self.routables.count - index)];
        return YES;
    }
}

- (BOOL)routableInStack:(id<ReduxyRoutable>)routable {
    for (NSDictionary *info in self.routables) {
        NSNumber *hash = info[@"hash"];
        NSString *path = info[@"path"];
        
        if ([hash isEqualToNumber:@(routable.hash)] &&
            [path isEqualToString:[routable.class path]])
        {
            return YES;
        }
    }
    
    return NO;
}


#pragma mark - dispatch

- (void)routePath:(NSString *)path context:(NSDictionary *)context {
    [self routePath:path context:context completion:nil];
}

- (void)unroutePath:(NSString *)path context:(NSDictionary *)context {
    [self unroutePath:path context:context completion:nil];
}

- (void)routePath:(NSString *)path context:(NSDictionary *)context completion:(void (^)(void))completion {
    NSAssert(path, @"No path to route");
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path }];
    
    if (completion) {
        [payload setObject:completion forKey:@"completion"];
    }
    if (context) {
        [payload addEntriesFromDictionary:context];
    }
    
    [self.store dispatch:ratype(router.route) payload:payload.copy];
}

- (void)unroutePath:(NSString *)path context:(NSDictionary *)context completion:(void (^)(void))completion {
    NSAssert(path, @"No path to unroute");
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path }];
    
    if (completion) {
        [payload setObject:completion forKey:@"completion"];
    }
    if (context) {
        [payload addEntriesFromDictionary:context];
    }
    
    [self.store dispatch:ratype(router.unroute) payload:payload.copy];
}

- (void)routeToPath:(NSString *)path context:(NSDictionary *)context {
    NSMutableDictionary *mcontext = [NSMutableDictionary dictionaryWithObject:@YES forKey:@"multi-depth"];
    
    if (context) {
        [mcontext addEntriesFromDictionary:context];
    }
    
    [self routePath:path context:mcontext.copy completion:nil];
}

- (void)unrouteToPath:(NSString *)path context:(NSDictionary *)context {
    NSMutableDictionary *mcontext = [NSMutableDictionary dictionaryWithObject:@YES forKey:@"multi-depth"];
    
    if (context) {
        [mcontext addEntriesFromDictionary:context];
    }
    
    [self unroutePath:path context:mcontext.copy completion:nil];
}


#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' will move to parent: %@", [vc.class path], parent);
    
    BOOL detached = (parent == nil);
    if (detached) {
    }
}

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' did move to parent: %@", [vc.class path], parent);
    
    // NOTE: 이 메시지는 한번 이상 호출 될 수 있다.
    
    /**
     TODO: 로직 검증 필요
     * setViewControllers: 라던가 여러단계의 뷰전환이 일어나는 상황에서 정상 동작하는가?
     * 제스쳐나 포스터치로의 자동 뷰 전환에서 모두 정상동작 하는가?
     */

    /// call didRoute:/didUnroute: to complete non-manual routing
    BOOL attached = (parent != nil);
    if (attached) {
        [self didRoute:vc];
    }
    else {
        [self didUnroute:vc];
    }
}

- (void)willUnrouteForPath:(NSString *)path from:(id<ReduxyRoutable>)routable {
    LOG_HERE
    
#if DEBUG
    LOG(@"will unroute, path: %@", path);
#endif

    self.unroutingInfo = @{ @"path": path,
                            @"hash": @(routable.hash) };
}

- (BOOL)didUnroute:(id<ReduxyRoutable>)routable {
    LOG_HERE
    
    id<ReduxyRoutable> top = [self topRoutable];
    NSString *topPath = [top.class path];
    NSString *path = [routable.class path];
    
#if DEBUG
    LOG(@"did unroute, path: %@", path);
#endif
    
    BOOL manualUnrouting = (self.unroutingInfo != nil);
    BOOL onTopYet = (top.hash == routable.hash &&
                     [topPath isEqualToString:path]);
    
    
    BOOL inStack = [self routableInStack:routable];
    
    if (manualUnrouting) {
        if (onTopYet) {
            [self popRoutable];
        }
        
        self.unroutingInfo = nil;
    }
    else {
#if 1 // multi depth
        if (inStack) {
            if ([self popRoutablesToRoutable:routable]) {
                [self.store dispatch:ratype(router.unroute)
                             payload:@{ @"path":  path,
                                        @"way": @"auto",
                                        @"depth": @"multi-able" }];
            }
        }
        else {
            // ignore
            LOG(@"ignore when routable is already out of stack");
        }
#else
        if (onTopYet) {
            [self popRoutable];
            
            [self.store dispatch:ratype(router.unroute)
                         payload:@{ @"path":  path,
                                    @"way": @"auto" }];
        }
        else {
            // ignore
            LOG(@"ignore when routable is already out of stack");
        }
#endif
    }
    
    return YES;
}

- (void)willRouteForPath:(NSString *)path from:(id<ReduxyRoutable>)routable {

#if DEBUG
    LOG(@"path: %@", path);
#endif

    self.routingInfo = @{ @"path": path,
                          @"hash": @(routable.hash) };

}

- (BOOL)didRoute:(id<ReduxyRoutable>)routable {
    
    NSString *routedPath = [routable.class path];
    
#if DEBUG
    LOG(@"did route, path: %@", routedPath);
#endif
    
    BOOL manualRouting = (self.routingInfo != nil);
    if (manualRouting) {
        NSString *routingPath = self.routingInfo[@"path"];
        
        if ([routingPath isEqualToString:routedPath]) {
            [self pushRoutable:routable path:routedPath];
            self.routingInfo = nil;
        }
        else {
            LOG(@"ignore, it is not the routable waiting");
        }
    }
    else {
        BOOL alreadyInStack = NO;
        
        for (NSDictionary *info in self.routables) {
            NSString *path = info[@"path"];
            NSNumber *hash = info[@"hash"];
            
            alreadyInStack = ([hash isEqualToNumber:@(routable.hash)] &&
                              [path isEqualToString:routedPath]);
            if (alreadyInStack)
                break ;
        }
        
        if (alreadyInStack) {
            // ignore
            LOG(@"ignore when routable is already on stack");
        }
        else {
            [self pushRoutable:routable path:routedPath];
            
            [self.store dispatch:ratype(router.route)
                         payload:@{ @"path":  routedPath,
                                    @"way": @"auto" }];
        }
    }
    
    return YES;
}


#pragma mark - ReduxyStoreSubscriber


- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    LOG(@"action: %@, state: %@", action, state);
    
    if (self.routesByAction) {
        [self routeByAction:action state:state];
    }
    else {
        
        //    [self routeByState:state];
        
        //[self routeMultiDepthByState:state action:action];
        [self routeMultiDepthByState2:state action:action];
    }
}

- (void)routeByAction:(ReduxyAction)action state:(ReduxyState)state {
    if ([action is:ratype(router.route)]) {
        NSString *path = action.payload[@"path"];
        
        LOG(@"router subscriber> route action: %@", path);
        
        if (![self route:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Route failed: %@", action]
                                         userInfo:state];
        }
    }
    else if ([action is:ratype(router.unroute)]) {
        NSString *path = action.payload[@"path"];
        
        LOG(@"router subscriber> unroute action: %@", path);
        
        if (![self unroute:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"unroute failed: %@", action]
                                         userInfo:state];
        }
    }
}

- (void)routeByState:(ReduxyState)state {
    NSArray *routes = routesSelector(state);
    
    NSArray *pathsInState = [routes valueForKey:@"path"];
    NSArray *pathsInRouter = [self.routables valueForKey:@"path"];
    
    LOG(@"router subscriber> paths in state: %@", pathsInState);
    LOG(@"router subscriber> paths in router: %@", pathsInRouter);
    
    if (pathsInState.count > pathsInRouter.count) {
        // push
        NSString *path = pathsInState.lastObject;
        
        LOG(@"router subscriber> route action: %@", path);
        
        ReduxyAction action = raction_payload(router.route.by-state, @{ @"path": path });
        
        if (![self route:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Route failed: %@", action]
                                         userInfo:state];
        }
    }
    else if (pathsInState.count < pathsInRouter.count) {
        // pop
        NSString *path = pathsInRouter.lastObject;
        
        LOG(@"router subscriber> unroute action: %@", path);
        
        ReduxyAction action = raction_payload(router.unroute.by-state, @{ @"path": path });
        
        if (![self unroute:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"unroute failed: %@", action]
                                         userInfo:state];
        }
    }
    else {
        // same routes
        LOG(@"same route");
    }
}

- (void)routeMultiDepthByState:(ReduxyState)state action:(ReduxyAction)action {
    NSArray *routes = routesSelector(state);
    
    NSArray *pathsInState = [routes valueForKey:@"path"];
    NSArray *pathsInRouter = [self.routables valueForKey:@"path"];
    
    LOG(@"router subscriber> paths in state: %@", pathsInState);
    LOG(@"router subscriber> paths in router: %@", pathsInRouter);
    
    if (pathsInState.count > pathsInRouter.count) {
        // push
        NSString *path = pathsInState.lastObject;
        
        LOG(@"router subscriber> route action: %@", path);
        
        if (![self route:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Route failed: %@", action]
                                         userInfo:state];
        }
    }
    else if (pathsInState.count < pathsInRouter.count) {
        // pop
        NSString *path = pathsInRouter.lastObject;
        
        LOG(@"router subscriber> unroute action: %@", path);
        
        if (![self unroute:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"unroute failed: %@", action]
                                         userInfo:state];
        }
    }
    else {
        // same routes
        LOG(@"same route");
    }
}


- (void)routeMultiDepthByState2:(ReduxyState)state action:(ReduxyAction)action {
    NSArray *routes = routesSelector(state);
    
    NSArray *pathsInState = [routes valueForKey:@"path"];
    NSArray *pathsInRouter = [self.routables valueForKey:@"path"];
    
    LOG(@"router subscriber> paths in state: %@", pathsInState);
    LOG(@"router subscriber> paths in router: %@", pathsInRouter);
    
    if (pathsInState.count > pathsInRouter.count) {
        // push
        NSString *path = pathsInState.lastObject;
        
        LOG(@"router subscriber> route action: %@", path);
        
        if (![self route:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Route failed: %@", action]
                                         userInfo:state];
        }
    }
    else if (pathsInState.count < pathsInRouter.count) {
        // pop
        NSString *path = pathsInRouter.lastObject;
        
        LOG(@"router subscriber> unroute action: %@", path);
        
        if (![self unroute:action state:state]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"unroute failed: %@", action]
                                         userInfo:state];
        }
    }
    else {
        // same routes
        LOG(@"same route");
    }
}



@end
