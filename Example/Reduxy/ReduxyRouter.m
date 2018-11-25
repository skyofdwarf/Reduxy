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
                                   reason:@"ReduxyRouter do not allow to use a raw instance of UIViewController as a routable"
                                 userInfo:nil];
}

- (UIViewController *)vc {
    return self;
}

- (void)reduxyrouter_willMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    
    if ([self conformsToProtocol:@protocol(ReduxyRoutable)]) {
        [ReduxyRouter.shared viewController:self willMoveToParentViewController:parent];
    }
}

- (void)reduxyrouter_didMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    
    if ([self conformsToProtocol:@protocol(ReduxyRoutable)]) {
        [ReduxyRouter.shared viewController:self didMoveToParentViewController:parent];
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
        
        __weak typeof(self) wself = self;
        route(routable, context, ^(id<ReduxyRoutable> dest) {
            [wself didRoute:dest];
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
        
        // do manual unroute
        __weak typeof(self) wself = self;
        unroute(routable, context, ^(id<ReduxyRoutable> dest) {
            [wself didUnroute:dest];
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
                
                NSMutableArray *mroutes = [NSMutableArray arrayWithArray:routes];
                
                NSString *pathToPop = action.payload[@"path"];
                
                NSDictionary *topPathInfo = routes.lastObject;
                NSString *topPath = topPathInfo[@"path"];
                
                if ([topPath isEqualToString:pathToPop]) {
                    LOG(@"route reducer> pop the path: %@", pathToPop);
                    [mroutes removeLastObject];
                }
                else {
                    LOG(@"route reducer> not found the path: %@", pathToPop);
                    
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                                   reason:[NSString stringWithFormat:@"Not found a path to pop: %@", pathToPop]
                                                 userInfo:state];
                }
                
                [mstate setObject:mroutes.copy forKey:ReduxyRouter.stateKey];
                
                return [mstate copy];
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
    NSString *way  = action.payload[@"way"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    if (self.routesAutoway || !way) {
        id<ReduxyRoutable> routable = [self topRoutable];
        return [self route:path source:routable context:action.payload];
    }
    
    BOOL autorouting = (way != nil);
    return autorouting;
}

- (BOOL)unroute:(ReduxyAction)action state:(ReduxyState)state  {
    NSString *path  = action.payload[@"path"];
    NSString *way  = action.payload[@"way"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    if (self.routesAutoway || !way) {
        id<ReduxyRoutable> routable = [self topRoutable];
        return [self unroute:path source:routable context:action.payload];
    }
    
    BOOL autorouting = (way != nil);
    return autorouting;
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

- (BOOL)popRoutableWithRoutable:(id<ReduxyRoutable>)routable {
    NSDictionary *info = self.routables.lastObject;
    NSNumber *hash = info[@"hash"];
    
    if ([hash isEqualToNumber:@(routable.hash)]) {
        [self popRoutable];
        return YES;
    }
    
    return NO;
}

- (BOOL)popRoutableWithPath:(NSString *)path {
    NSDictionary *info = self.routables.lastObject;
    NSString *topPtah = info[@"path"];
    
    if ([topPtah isEqualToString:path]) {
        [self popRoutable];
        return YES;
    }
    
    return NO;
}

#pragma mark - dispatch

- (void)dispatchRoute:(id)payload {
    [self.store dispatch:ratype(router.route)
                 payload:payload];
}

- (void)dispatchUnroute:(id)payload {
    [self.store dispatch:ratype(router.unroute)
                 payload:payload];
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
    
    if (manualUnrouting) {
        if (onTopYet) {
            [self popRoutable];
        }
        
        self.unroutingInfo = nil;
    }
    else {
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
    
//    [self routeByAction:action state:state];
    
    [self routeByState:state];
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
    NSArray *pathsInNow = [self.routables valueForKey:@"path"];
    
    if (pathsInState.count > pathsInNow.count) {
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
    else if (pathsInState.count < pathsInNow.count) {
        // pop
        NSString *path = pathsInNow.lastObject;
        
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


@end
