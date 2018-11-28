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

static const NSInteger routable_order_association_key = 0;

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

@property (strong, nonatomic) NSMutableArray<NSArray<id<ReduxyRoutable>> *> *fromToPairs;

@property (copy, nonatomic) NSDictionary *routingInfo;
@property (copy, nonatomic) NSDictionary *unroutingInfo;

@property (assign, atomic) NSUInteger order;

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
        self.fromToPairs = [NSMutableArray array];
        
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

- (NSNumber *)allocateOrderToRoutableIfNeeded:(id<ReduxyRoutable>)routable {
    id r = objc_getAssociatedObject(routable, &routable_order_association_key);
    if (!r) {
        NSUInteger order = self.order++;
        objc_setAssociatedObject(routable, &routable_order_association_key, @(order), OBJC_ASSOCIATION_COPY);
        
        return @(order);
    }
    
    return r;
}

- (NSNumber *)orderOfRoutable:(id<ReduxyRoutable>)routable {
    id r = objc_getAssociatedObject(routable, &routable_order_association_key);
    
    NSAssert(r, @"No order set");
    
    return r;
}


- (NSArray<id<ReduxyRoutable>> *)findFromToPairWithFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to {
    for (NSArray *pair in self.fromToPairs) {
        if ([pair.firstObject isEqual:from] && [pair.lastObject isEqual:to])
            return pair;
    }
    return nil;
}

- (NSArray<id<ReduxyRoutable>> *)findFromToPairWithTo:(id<ReduxyRoutable>)to {
    NSMutableArray *pairs = [NSMutableArray array];
    
    for (NSArray *pair in self.fromToPairs) {
        if ([pair.lastObject isEqual:to]) {
            //return pair;
            [pairs addObject:pair];
        }
    }
    
    NSAssert(pairs.count == 1, @"A routable must be exist one as 'to' in from-to pairs");
    
    return pairs.firstObject;
}

- (NSArray<NSArray<id<ReduxyRoutable>> *> *)findFromToPairsWithToPath:(NSString *)path {
    NSMutableArray<NSArray<id<ReduxyRoutable>> *> *pairs = [NSMutableArray array];
    
    for (NSArray *pair in self.fromToPairs) {
        id<ReduxyRoutable> to = pair.lastObject;
        
        if ([to.path isEqualToString:path]) {
            [pairs addObject:pair];
        }
    }
    return pairs.copy;
}

- (NSArray<id<ReduxyRoutable>> *)findFromToPairWithToPath:(NSString *)path toHash:(NSNumber *)hash {
    NSArray<NSArray<id<ReduxyRoutable>> *> *pairs = [self findFromToPairsWithToPath:path];
    
    if (hash) {
        for (NSArray<id<ReduxyRoutable>> *pair in pairs) {
            id<ReduxyRoutable> to = pair.lastObject;
            if ([hash isEqualToNumber:@(to.hash)])
                return pair;
        }
        return nil;
    }
    else {
        NSAssert(pairs.count <= 1, @"finding pair without hash must be one or zero");
        
        return pairs.firstObject;
    }
}

- (NSArray<id<ReduxyRoutable>> *)routablesInFromToPairsWithPath:(NSString *)path {
    NSMutableSet *set = [NSMutableSet set];
    for (NSArray<id<ReduxyRoutable>> *pair in self.fromToPairs) {
        id<ReduxyRoutable> from = pair.firstObject;
        id<ReduxyRoutable> to = pair.lastObject;
        
        [set addObject:from];
        [set addObject:to];
    }
    
    return set.allObjects;
}

- (id<ReduxyRoutable>)findFromToPairWithPath:(NSString *)path hash:(NSNumber *)hash {
    NSArray<id<ReduxyRoutable>> *routables = [self routablesInFromToPairsWithPath:path];
    
    if (hash) {
        for (id<ReduxyRoutable> routable in routables) {
            if ([path isEqualToString:routable.path] &&
                [hash isEqualToNumber:@(routable.hash)])
            {
                return routable;
            }
        }
        return nil;
    }
    else {
        NSAssert(routables.count <= 1, @"finding pair without hash must be one or zero");
        
        return routables.firstObject;
    }
}


- (NSArray<NSArray<id<ReduxyRoutable>> *> *)findFromToPairsWithFrom:(id<ReduxyRoutable>)from {
    NSMutableArray *pairs = [NSMutableArray array];
    
    for (NSArray *pair in self.fromToPairs) {
        if ([pair.firstObject isEqual:from])
            [pairs addObject:pair];
    }
    return pairs.copy;
}

- (void)addFromToPairWithFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to {
    [self.fromToPairs addObject:@[ from, to ]];
}

- (void)removeFromToPairByTo:(id<ReduxyRoutable>)to {
    NSArray<id<ReduxyRoutable>> *pair = [self findFromToPairWithTo:to];
    [self.fromToPairs removeObject:pair];
}

- (void)removeFromToPairsByFrom:(id<ReduxyRoutable>)from {
    NSArray<NSArray<id<ReduxyRoutable>> *> *pairs = [self findFromToPairsWithFrom:from];
 
    [self.fromToPairs removeObjectsInArray:pairs];
}


- (void)addRoutable:(id<ReduxyRoutable>)routable {
    NSString *path = routable.path;
    NSNumber *order = [self allocateOrderToRoutableIfNeeded:routable];
    
    NSMutableDictionary *routables = [self routablesForPath:path];
    
    [routables setObject:@{ @"routable": routable,
                            @"path": path,
                            @"order": order,
                            }
                  forKey:order];
    
    [self.routables setValue:routables forKey:path];
}

- (void)removeRoutable:(id<ReduxyRoutable>)routable {
    NSString *path = routable.path;
    
    NSMutableDictionary *routables = [self routablesForPath:path];
    
    NSNumber *order = [self orderOfRoutable:routable];
    
    [routables removeObjectForKey:order];
}

- (NSMutableDictionary *)routablesForPath:(NSString *)path {
    NSMutableDictionary *routables = [self.routables objectForKey:path];
    if (routables) {
        return routables;
    }
    return [NSMutableDictionary dictionary];
}

- (id<ReduxyRoutable>)routableForPath:(NSString *)path order:(NSNumber *)order {
    NSMutableDictionary *routables = [self routablesForPath:path];
    return routables[order][@"routable"];
}

- (BOOL)routableInStack:(id<ReduxyRoutable>)routable {
    NSNumber *order = [self orderOfRoutable:routable];
    
    return ([self routableForPath:routable.path order:order] != nil);
}

- (BOOL)route:(NSString *)path source:(id<ReduxyRoutable>)routable context:(id)context {
    RouteAction route = self.routes[path];
    if (route) {
        [self willRouteForPath:path from:routable];
        
        __weak typeof(self) wself = self;
        id<ReduxyRoutable> to = route(routable, context, ^(id<ReduxyRoutable> from, id<ReduxyRoutable> to) {
            [wself didRouteFrom:from to:to];
        });
        [self allocateOrderToRoutableIfNeeded:to];
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
        unroute(routable, context, ^(id<ReduxyRoutable> from, id<ReduxyRoutable> to) {
            [wself didUnrouteFrom:from to:to];
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
        NSNumber *fromOrder  = action.payload[@"from-order"];
        
        id<ReduxyRoutable> from = [self routableForPath:fromPath order:fromOrder];
        
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
        NSNumber *fromOrder  = action.payload[@"from-order"];
        
        id<ReduxyRoutable> from = [self routableForPath:fromPath order:fromOrder];
        
        return [self unroute:path source:from context:action.payload];
    }
    
    BOOL autorouting = (way != nil);
    return autorouting;
    
}

#pragma mark - dispatch

- (void)routePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context {
    NSAssert(path, @"No path to route");
    
    NSNumber *order = [self orderOfRoutable:from];
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path,
                                                                                    @"from-path": from.path,
                                                                                    @"from-order": order,
                                                                                    }];
    if (context) {
        [payload addEntriesFromDictionary:context];
    }
    
    [self.store dispatch:ratype(router.route) payload:payload.copy];
}

- (void)unroutePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context {
    NSAssert(path, @"No path to unroute");
    
    NSNumber *order = [self orderOfRoutable:from];
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path,
                                                                                    @"from-path": from.path,
                                                                                    @"from-order": order,
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
        [self didRouteFrom:parent to:vc];
    }
    else {
        [self didUnrouteFrom:vc to:parent];
    }
}

- (void)willUnrouteForPath:(NSString *)path from:(id<ReduxyRoutable>)from {
    LOG_HERE
    
#if DEBUG
    LOG(@"will unroute, path: %@", path);
#endif

    self.unroutingInfo = @{ @"path": path,
                            @"order": [self orderOfRoutable:from],
                            };
}

- (BOOL)didUnrouteFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to {
    LOG_HERE
    
#if DEBUG
    LOG(@"did unroute, from: '%@' to: '%@'", from.path, to.path);
#endif
    
    BOOL manualUnrouting = (self.unroutingInfo != nil);
    
    BOOL inStack = [self routableInStack:from];
    
    if (manualUnrouting) {
        LOG(@"manuall way");
        if (inStack) {
            LOG(@"pop routables to path: %@", from.path);
            
            NSArray<id<ReduxyRoutable>> *pair = [self findFromToPairWithTo:from];
            
            [self removeRoutable:from];
            [self removeFromToPairByTo:from];
        }
        
        self.unroutingInfo = nil;
    }
    else {
        LOG(@"auto way");

        if (inStack) {
            LOG(@"pop routables to path: %@", from.path);
            
            NSArray<id<ReduxyRoutable>> *pair = [self findFromToPairWithTo:from];
            
            [self removeRoutable:from];
            [self removeFromToPairByTo:from];
            
            [self.store dispatch:ratype(router.unroute)
                         payload:@{ @"path": from.path,
                                    @"from-path": from.path,
                                    @"from-order": [self orderOfRoutable:from],
                                    @"way": @"auto",
                                    }];
        }
        else {
            // ignore
            LOG(@"ignore when routable is already out of stack");
        }
    }
    
    return YES;
}

- (void)willRouteForPath:(NSString *)path from:(id<ReduxyRoutable>)from {

#if DEBUG
    LOG(@"path: %@", path);
#endif

    self.routingInfo = @{ @"path": path,
                          @"order": [self orderOfRoutable:from],
                          };

}

- (BOOL)didRouteFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to {
    
#if DEBUG
    LOG(@"did route, from: '%@' to: '%@'", from.path, to.path);
#endif
    
    [self allocateOrderToRoutableIfNeeded:from];
    [self allocateOrderToRoutableIfNeeded:to];
    
    BOOL manualRouting = (self.routingInfo != nil);
    if (manualRouting) {
        LOG(@"manual way");
        
        NSString *routingPath = self.routingInfo[@"path"];
        
        if ([routingPath isEqualToString:to.path]) {
            LOG(@"push routable: %@", to.path);
            
            [self addRoutable:to];
            [self addFromToPairWithFrom:from to:to];
            
            self.routingInfo = nil;
        }
        else {
            LOG(@"ignore, it is not the routable waiting");        }
    }
    else {
        LOG(@"auto way");
        
        BOOL alreadyInStack = [self routableInStack:to];
        if (alreadyInStack) {
            // ignore
            LOG(@"ignore when routable is already on stack");
        }
        else {
            LOG(@"push routable: %@", to.path);
            
            [self addRoutable:to];
            [self addFromToPairWithFrom:from to:to];
            
            [self.store dispatch:ratype(router.route)
                         payload:(from?
                                  @{ @"path": to.path,
                                     @"from-path": from.path,
                                     @"from-order": [self orderOfRoutable:from],
                                     @"way": @"auto"
                                     }:
                                  @{ @"path": to.path,
                                     @"way": @"auto"
                                     })
             ];
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
