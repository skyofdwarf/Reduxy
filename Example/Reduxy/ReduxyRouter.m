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

static const NSInteger routingSequenceAssoociationKey = 0;

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

@property (strong, nonatomic) NSMutableSet<NSArray<id<ReduxyRoutable>> *> *routingTable;

@property (copy, nonatomic) NSDictionary *routingInfo;
@property (copy, nonatomic) NSDictionary *unroutingInfo;

@property (assign, atomic) NSUInteger routingSequence;

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
        self.routingTable = [NSMutableSet set];
        
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

#pragma mark - register

- (void)add:(NSString *)path route:(RouteAction)route unroute:(RouteAction)unroute {
    self.routes[path] = route;
    self.unroutes[path] = unroute;
}

- (void)remove:(NSString *)path {
    self.routes[path] = nil;
    self.unroutes[path] = nil;
}

#pragma mark - routable sequence

- (NSNumber *)tagSequenceToRoutableIfNeeded:(id<ReduxyRoutable>)routable {
    NSParameterAssert(routable);
    
    id r = objc_getAssociatedObject(routable, &routingSequenceAssoociationKey);
    if (!r) {
        NSUInteger seq = self.routingSequence++;
        objc_setAssociatedObject(routable, &routingSequenceAssoociationKey, @(seq), OBJC_ASSOCIATION_COPY);
        
        return @(seq);
    }
    
    return r;
}

- (NSNumber *)sequenceOfRoutable:(id<ReduxyRoutable>)routable {
    NSParameterAssert(routable);
    
    id r = objc_getAssociatedObject(routable, &routingSequenceAssoociationKey);
    
    NSAssert(r, @"No sequence set");
    
    return r;
}

#pragma mark - routing tabls

- (void)addRoutingWithFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to {
    NSParameterAssert(from);
    NSParameterAssert(to);
    
    if (![self.routingTable containsObject:@[ from, to ]]) {
        [self.routingTable addObject:@[ from, to ]];
    }
}

- (void)removeRoutingInTableWithFrom:(id<ReduxyRoutable>)from {
    NSParameterAssert(from);
    
    NSArray<NSArray<id<ReduxyRoutable>> *> *pairs = [self findRoutingsInTabelWithFrom:from];
    
    for (NSArray<id<ReduxyRoutable>> *pair in pairs) {
        [self.routingTable removeObject:pair];
    }
}

- (void)removeRoutingInTableWithTo:(id<ReduxyRoutable>)to {
    NSParameterAssert(to);
    
    NSArray<id<ReduxyRoutable>> *pair = [self findRoutingInTabelWithTo:to];
    [self.routingTable removeObject:pair];
}

- (NSArray<id<ReduxyRoutable>> *)routablesInRoutingTable {
    NSMutableSet *routables = [NSMutableSet set];
    for (NSArray<id<ReduxyRoutable>> *pair in self.routingTable) {
        [routables addObject:pair.firstObject];
        [routables addObject:pair.lastObject];
    }
    return routables.allObjects;
}

- (NSArray<id<ReduxyRoutable>> *)fromRoutablesInRoutingTable {
    NSMutableSet *routables = [NSMutableSet set];
    for (NSArray<id<ReduxyRoutable>> *pair in self.routingTable) {
        [routables addObject:pair.firstObject];
    }
    return routables.allObjects;
}

- (NSArray<id<ReduxyRoutable>> *)toRoutablesInRoutingTable {
    NSMutableSet *routables = [NSMutableSet set];
    for (NSArray<id<ReduxyRoutable>> *pair in self.routingTable) {
        [routables addObject:pair.lastObject];
    }
    return routables.allObjects;
}

- (BOOL)isRoutableInRoutingTable:(id<ReduxyRoutable>)routable {
    NSArray *routables = [self routablesInRoutingTable];
    return [routables containsObject:routable];
}

- (BOOL)isRoutableInRoutingTableAsFrom:(id<ReduxyRoutable>)from {
    NSParameterAssert(from);
    
    NSArray *routables = [self fromRoutablesInRoutingTable];
    return [routables containsObject:from];
}

- (BOOL)isRoutableInRoutingTableAsTo:(id<ReduxyRoutable>)to {
    NSParameterAssert(to);
    
    NSArray *routables = [self toRoutablesInRoutingTable];
    return [routables containsObject:to];
}

- (id<ReduxyRoutable>)findRoutableWithPath:(NSString *)path sequence:(NSNumber *)sequence {
    NSParameterAssert(path);
    NSParameterAssert(sequence);
    
    NSArray *routables = [self routablesInRoutingTable];
    for (id<ReduxyRoutable> routable in routables) {
        if ([routable.path isEqualToString:path] &&
            [[self sequenceOfRoutable:routable] isEqualToNumber:sequence])
        {
            return routable;
        }
    }
    return nil;
}

- (NSArray<id<ReduxyRoutable>> *)findRoutingInTabelWithTo:(id<ReduxyRoutable>)to {
    NSParameterAssert(to);
    
    NSMutableArray *pairs = [NSMutableArray array];
    
    for (NSArray *pair in self.routingTable) {
        if ([pair.lastObject isEqual:to]) {
            [pairs addObject:pair];
        }
    }
    
    NSAssert(pairs.count <= 1, @"A routable must be exist one or zero as 'to' in from-to pairs");
    
    return pairs.firstObject;
}

- (NSArray<NSArray<id<ReduxyRoutable>> *> *)findRoutingsInTabelWithFrom:(id<ReduxyRoutable>)from {
    NSParameterAssert(from);
    
    NSMutableArray *pairs = [NSMutableArray array];
    
    for (NSArray *pair in self.routingTable) {
        if ([pair.firstObject isEqual:from]) {
            [pairs addObject:pair];
        }
    }
    
    return pairs.copy;
}

#pragma mark - routes

- (void)route:(NSString *)path source:(id<ReduxyRoutable>)routable context:(id)context {
    NSParameterAssert(path);
    NSParameterAssert(routable);
    
    RouteAction route = self.routes[path];
    NSAssert(route, @"No route for path '%@'", path);
    
    if (route) {
        [self willRouteForPath:path from:routable];
        
        __weak typeof(self) wself = self;
        route(routable, context, ^(id<ReduxyRoutable> from, id<ReduxyRoutable> to) {
            [wself didRouteFrom:from to:to];
        });
    }
}

- (void)unroute:(NSString *)path source:(id<ReduxyRoutable>)routable context:(id)context {
    NSParameterAssert(path);
    NSParameterAssert(routable);
    
    RouteAction unroute = self.unroutes[path];
    NSAssert(unroute, @"No unroute for path '%@'", path);
    
    if (unroute) {
        [self willUnrouteForPath:path from:routable];
        
        // do manual unroute
        __weak typeof(self) wself = self;
        unroute(routable, context, ^(id<ReduxyRoutable> from, id<ReduxyRoutable> to) {
            [wself didUnrouteFrom:from to:to];
        });
    }
}

- (BOOL)routeWithAction:(ReduxyAction)action {
    NSParameterAssert(action);
    
    NSString *path  = action.payload[@"path"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    NSString *way  = action.payload[@"way"];
    BOOL autorouting = (way != nil);
    
    if (self.routesAutoway || !autorouting) {
        NSString *fromPath = action.payload[@"from-path"];
        NSNumber *fromSeq  = action.payload[@"from-seq"];
        
        id<ReduxyRoutable> from = [self findRoutableWithPath:fromPath sequence:fromSeq];
        [self route:path source:from context:action.payload];
        return YES;
    }
    
    
    return autorouting;
}

- (BOOL)unrouteWithAction:(ReduxyAction)action {
    NSParameterAssert(action);
    
    NSString *path  = action.payload[@"path"];
    
    NSAssert([path isKindOfClass:NSString.class], @"the `path` must be kined of NSString");
    
    NSString *way  = action.payload[@"way"];
    
    BOOL autorouting = (way != nil);
    
    if (self.routesAutoway || !autorouting) {
        NSString *fromPath = action.payload[@"from-path"];
        NSNumber *fromSeq  = action.payload[@"from-seq"];
        
        /// multiple unroute actions are callable with same path
        /// so -findRoutableWithPath:sequence: return nil for routable alredy removed in routing table
        id<ReduxyRoutable> from = [self findRoutableWithPath:fromPath sequence:fromSeq];
        if (from) {
            [self unroute:path source:from context:action.payload];
        }
        return YES;
    }
    
    return autorouting;
    
}

#pragma mark - dispatch

- (void)routePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context {
    NSParameterAssert(path);
    NSParameterAssert(from);
    
    NSNumber *seq = [self sequenceOfRoutable:from];
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path,
                                                                                    @"from-path": from.path,
                                                                                    @"from-seq": seq,
                                                                                    }];
    if (context) {
        [payload addEntriesFromDictionary:context];
    }
    
    [self.store dispatch:ratype(router.route) payload:payload.copy];
}

- (void)unroutePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context {
    NSParameterAssert(path);
    NSParameterAssert(from);
    
    NSNumber *seq = [self sequenceOfRoutable:from];
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ @"path": path,
                                                                                    @"from-path": from.path,
                                                                                    @"from-seq": seq,
                                                                                    }];
    
    if (context) {
        [payload addEntriesFromDictionary:context];
    }
    
    [self.store dispatch:ratype(router.unroute) payload:payload.copy];
}

#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' will move to parent: %@", [vc path], parent);
}

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' did move to parent: %@", [vc path], parent);
    
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
                            @"from-path": from.path,
                            @"from-seq": [self sequenceOfRoutable:from],
                            };
}

- (BOOL)didUnrouteFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to {
    LOG_HERE
    
#if DEBUG
    LOG(@"did unroute, from: '%@' to: '%@'", from.path, to.path);
#endif
    
    BOOL manualUnrouting = (self.unroutingInfo != nil);
    
    BOOL inStackAsTo = [self isRoutableInRoutingTableAsTo:from];
    
    if (manualUnrouting) {
        LOG(@"manuall way");
        if (inStackAsTo) {
            LOG(@"pop routables to path: %@", from.path);
            
            [self removeRoutingInTableWithTo:from];
        }
        
        self.unroutingInfo = nil;
    }
    else {
        LOG(@"auto way");

        if (inStackAsTo) {
            LOG(@"pop routables to path: %@", from.path);
            
            [self removeRoutingInTableWithTo:from];
            
            [self.store dispatch:ratype(router.unroute)
                         payload:@{ @"path": from.path,
                                    @"from-path": from.path,
                                    @"from-seq": [self sequenceOfRoutable:from],
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
                          @"from-path": from.path,
                          @"from-seq": [self sequenceOfRoutable:from],
                          };

}

- (BOOL)didRouteFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to {
    
#if DEBUG
    LOG(@"did route, from: '%@' to: '%@'", from.path, to.path);
#endif
    
    [self tagSequenceToRoutableIfNeeded:from];
    [self tagSequenceToRoutableIfNeeded:to];
    
    if (from) {
        NSArray<id<ReduxyRoutable>> *routing = [self findRoutingInTabelWithTo:to];
        if (!routing) {
            [self addRoutingWithFrom:from to:to];
        }
    }
    
    BOOL manualRouting = (self.routingInfo != nil);
    if (manualRouting) {
        LOG(@"manual way");
        
        NSString *routingPath = self.routingInfo[@"path"];
        
        if ([routingPath isEqualToString:to.path]) {
            LOG(@"push routable: %@", to.path);
            
            self.routingInfo = nil;
        }
        else {
            LOG(@"ignore, it is not the routable waiting");
        }
    }
    else {
        LOG(@"auto way");
        
        BOOL alreadyInStack = [self isRoutableInRoutingTable:to];
        if (alreadyInStack) {
            // ignore
            LOG(@"ignore when routable is already on stack");
        }
        else {
            LOG(@"push routable: %@", to.path);
            
            [self.store dispatch:ratype(router.route)
                         payload:(from?
                                  @{ @"path": to.path,
                                     @"from-path": from.path,
                                     @"from-seq": [self sequenceOfRoutable:from],
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
