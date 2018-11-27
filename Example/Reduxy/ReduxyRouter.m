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

- (NSString *)path {
    return self.description;
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
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSMutableDictionary *> *routables;

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
        self.routables = [NSMutableDictionary dictionary];
        
        self.routesAutoway = NO;
        self.routesByAction = YES;
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

- (void)setInitialRoutables:(NSArray<id<ReduxyRoutable>> *)routables {
    for (id<ReduxyRoutable> routable in routables) {
        [self addRoutable:routable];
    }
}
    
#pragma mark - redux


- (ReduxyReducerTransducer)reducer {
    return [self reducerWithInitialRoutables:@[]];
}

- (ReduxyReducerTransducer)reducerWithInitialRoutables:(NSArray<id<ReduxyRoutable>> *)routables {
    // builds root routing state
    NSMutableArray *initialState = @[].mutableCopy;
    
    for (id<ReduxyRoutable> routable in routables) {
        [self addRoutable:routable];
        
        [initialState addObject:@{ @"path": routable.path }];
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

//                    @throw [NSException exceptionWithName:NSInternalInconsistencyException
//                                                   reason:[NSString stringWithFormat:@"Not found a path to pop in stack: %@", pathToPop]
//                                                 userInfo:state];
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

- (void)addRoutable:(id<ReduxyRoutable>)routable {
    NSString *path = routable.path;
    
    NSMutableDictionary *routables = [self routablesForPath:path];
    
    [routables setValue:@{ @"routable": routable,
                           @"path": path,
                           @"hash": @(routable.hash),
                           }
                 forKey:@(routable.hash).stringValue];
    
    [self.routables setValue:routables forKey:path];
}

- (void)removeRoutable:(id<ReduxyRoutable>)routable {
    NSString *path = routable.path;
    
    NSMutableDictionary *routables = [self routablesForPath:path];
    
    [routables removeObjectForKey:@(routable.hash).stringValue];
}

- (NSMutableDictionary *)routablesForPath:(NSString *)path {
    NSMutableDictionary *routables = [self.routables objectForKey:path];
    if (routables) {
        return routables;
    }
    return [NSMutableDictionary dictionary];
}

- (id<ReduxyRoutable>)routableForPath:(NSString *)path hash:(NSNumber *)hash {
    NSMutableDictionary *routables = [self routablesForPath:path];
    return routables[hash.stringValue][@"routable"];
}

- (BOOL)routableInStack:(id<ReduxyRoutable>)routable {
    return ([self routableForPath:routable.path hash:@(routable.hash)] != nil);
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

- (BOOL)routeWithAction:(ReduxyAction)action {
    NSString *path  = action.payload[@"path"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    NSString *way  = action.payload[@"way"];
    
    if (self.routesAutoway || !way) {
        NSString *fromPath = action.payload[@"from-path"];
        NSNumber *fromHash = action.payload[@"from-hash"];
        
        id<ReduxyRoutable> from = [self routableForPath:fromPath hash:fromHash];
        return [self route:path source:from context:action.payload];
    }
    
    BOOL autorouting = (way != nil);
    return autorouting;
}

- (BOOL)unrouteWithAction:(ReduxyAction)action {
    NSString *path  = action.payload[@"path"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    NSString *way  = action.payload[@"way"];
    
    if (self.routesAutoway || !way) {
        NSString *fromPath = action.payload[@"from-path"];
        NSNumber *fromHash = action.payload[@"from-hash"];
        
        id<ReduxyRoutable> from = [self routableForPath:fromPath hash:fromHash];
        return [self unroute:path source:from context:action.payload];
    }
    
    BOOL autorouting = (way != nil);
    return autorouting;
    
}

#pragma mark - dispatch

- (void)routeFrom:(id<ReduxyRoutable>)from path:(NSString *)path context:(NSDictionary *)context {
    NSAssert(path, @"No path to route");
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path,
                                                                                    @"from-path": from.path,
                                                                                    @"from-hash": @(from.hash),
                                                                                    }];
    if (context) {
        [payload addEntriesFromDictionary:context];
    }
    
    [self.store dispatch:ratype(router.route) payload:payload.copy];
}

- (void)unrouteFrom:(id<ReduxyRoutable>)from path:(NSString *)path context:(NSDictionary *)context {
    NSAssert(path, @"No path to unroute");
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path,
                                                                                    @"from-path": from.path,
                                                                                    @"from-hash": @(from.hash),
                                                                                    }];
    
    if (context) {
        [payload addEntriesFromDictionary:context];
    }
    
    [self.store dispatch:ratype(router.unroute) payload:payload.copy];
}

#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' will move to parent: %@", [vc path], parent);
    
    BOOL detached = (parent == nil);
    if (detached) {
    }
}

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' did move to parent: %@", [vc path], parent);
    
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
    
#if DEBUG
    LOG(@"did unroute, path: %@", routable.path);
#endif
    
    BOOL manualUnrouting = (self.unroutingInfo != nil);
    
    BOOL inStack = [self routableInStack:routable];
    
    if (manualUnrouting) {
        LOG(@"manuall way");
        if (inStack) {
            LOG(@"pop routables to path: %@", routable.path);
            [self removeRoutable:routable];
        }
        
        self.unroutingInfo = nil;
    }
    else {
        LOG(@"auto way");
#if 1 // multi depth
        if (inStack) {
            LOG(@"pop routables to path: %@", routable.path);
            
            [self removeRoutable:routable];
            
            [self.store dispatch:ratype(router.unroute)
                         payload:@{ @"path":  routable.path,
                                    @"way": @"auto" }];
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
    
#if DEBUG
    LOG(@"did route, path: %@", routable.path);
#endif
    
    BOOL manualRouting = (self.routingInfo != nil);
    if (manualRouting) {
        LOG(@"manual way");
        
        NSString *routingPath = self.routingInfo[@"path"];
        
        if ([routingPath isEqualToString:routable.path]) {
            LOG(@"push routable: %@", routable.path);
            
            [self addRoutable:routable];
            
            self.routingInfo = nil;
        }
        else {
            LOG(@"ignore, it is not the routable waiting");
        }
    }
    else {
        LOG(@"auto way");
        
        BOOL alreadyInStack = [self routableInStack:routable];
        if (alreadyInStack) {
            // ignore
            LOG(@"ignore when routable is already on stack");
        }
        else {
            LOG(@"push routable: %@", routable.path);
            
            [self addRoutable:routable];
            
            [self.store dispatch:ratype(router.route)
                         payload:@{ @"path": routable.path,
                                    @"way": @"auto" }];
        }
    }
    
    return YES;
}


#pragma mark - ReduxyStoreSubscriber


- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    LOG(@"action: %@, state: %@", action, state);
    
    [self processRouteAction:action];
}

- (void)processRouteAction:(ReduxyAction)action {
    if ([action is:ratype(router.route)]) {
        NSString *path = action.payload[@"path"];
        
        LOG(@"router subscriber> route action: %@", path);
        
        if (![self routeWithAction:action]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Route failed: %@", action]
                                         userInfo:nil];
        }
    }
    else if ([action is:ratype(router.unroute)]) {
        NSString *path = action.payload[@"path"];
        
        LOG(@"router subscriber> unroute action: %@", path);
        
        if (![self unrouteWithAction:action]) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"unroute failed: %@", action]
                                         userInfo:nil];
        }
    }
}

@end
