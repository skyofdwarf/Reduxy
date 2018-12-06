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

#import "UIViewController+ReduxyRoutable.h"


static const NSInteger routePathAssoociationKey = 0;
static const NSInteger routableTageAssoociationKey = 0;



#pragma mark - ReduxyRouter

@interface ReduxyRouter () <ReduxyStoreSubscriber>
@property (strong, nonatomic) id<ReduxyStore> store;

@property (strong, nonatomic) NSMutableDictionary<NSString */*name*/, RouterTargetCreator> *targets;
@property (strong, nonatomic) NSMutableDictionary<NSString */*path*/, id> *paths;

@property (strong, nonatomic) NSMutableSet<id<ReduxyRoutable>> *routables;
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.targets = @{}.mutableCopy;
        self.paths = @{}.mutableCopy;
        self.routables = [NSMutableSet new];
        
        self.routesAutoway = NO;
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

#pragma mark - add

- (void)addTarget:(NSString *)name creator:(RouterTargetCreator)creator {
    self.targets[name] = creator;
}

- (void)removeTarget:(NSString *)name {
    [self.targets removeObjectForKey:name];
}


- (void)addPath:(NSString *)path targets:(NSArray<NSString *> *)targets route:(RouterRoute)route unroute:(RouterUnroute)unroute {
    self.paths[path] = @{ @"targets": targets,
                          @"route": route,
                          @"unroute": unroute,
                          };
}

- (void)removePath:(NSString *)path {
    [self.paths removeObjectForKey:path];
}

#pragma mark - route

- (NSDictionary *)preloadForPath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context {
    NSDictionary *pathInfo = self.paths[path];
    NSArray<NSString *> *targets = pathInfo[@"targets"];
    
    NSMutableDictionary *targetTags = @{}.mutableCopy;
    
    for (NSString *target in targets) {
        RouterTargetCreator creator = self.targets[target];
        id<ReduxyRoutable> routable = creator(from, context);
        
        NSString *tag = [NSString stringWithFormat:@"%p", routable];
        
        [self tagRoutable:routable value:tag];
        [self addRoutable:routable];
        
        objc_setAssociatedObject(routable, &routePathAssoociationKey, path, OBJC_ASSOCIATION_COPY);
        
        targetTags[target] = tag;
    }
    
    return targetTags.copy;
}

- (void)routePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context {
    [self addRoutable:from];
    
    NSString *fromTag = [self tagOfRoutable:from];
    NSDictionary *targetTags = [self preloadForPath:path from:from context:context];
    
    [self.store dispatch:ratype(router.route)
                 payload:@{ @"path": path,
                            @"from-path": from.path,
                            @"from-tag": fromTag,
                            @"target-tags": targetTags,
                            @"context": context ?: @{}
                            }
     ];
}

- (void)unroutePath:(NSString *)path from:(id<ReduxyRoutable>)from {
    NSString *fromTag = [self tagOfRoutable:from];
    
    [self.store dispatch:ratype(router.unroute)
                 payload:@{ @"path": path,
                            @"from-path": from.path,
                            @"from-tag": fromTag,
                            }
     ];
}

- (void)unrouteFrom:(id<ReduxyRoutable>)from {
    NSString *path = objc_getAssociatedObject(from, &routePathAssoociationKey);
    NSString *fromTag = [self tagOfRoutable:from];
    
    [self.store dispatch:ratype(router.unroute)
                 payload:@{ @"path": path,
                            @"from-path": from.path,
                            @"from-tag": fromTag,
                            }
     ];
}


#pragma mark - route action

- (void)routeAction:(ReduxyAction)action {
    NSNumber *implicit = action.payload[@"implicit"];
    
    if (!self.routesAutoway && implicit.boolValue) {
        return ;
    }
    
    NSString *path = action.payload[@"path"];
    NSString *fromPath = action.payload[@"from-path"];
    NSString *fromTag = action.payload[@"from-tag"];
    NSDictionary *context = action.payload[@"context"];
    NSDictionary *targetTags = action.payload[@"target-tags"];
    
    NSDictionary *pathInfo = self.paths[path];
    
    RouterRoute route = pathInfo[@"route"];
    
    NSMutableDictionary *to = @{}.mutableCopy;
    id<ReduxyRoutable> from = [self findRoutableWithPath:fromPath tag:fromTag];
    
    for (NSString *target in targetTags.allKeys) {
        NSString *tag = targetTags[target];
        
        id<ReduxyRoutable> routable = [self findRoutableWithPath:target tag:tag];
        if (routable) {
            to[target] = routable;
        }
        else {
            RouterTargetCreator creator = self.targets[target];
            id<ReduxyRoutable> routable = creator(from, context);
            
            to[target] = routable;
            
            [self tagRoutable:routable value:tag];
            [self addRoutable:routable];
            
            objc_setAssociatedObject(routable, &routePathAssoociationKey, path, OBJC_ASSOCIATION_COPY);
        }
    }
    
    route(from, to, context, ^(id<ReduxyRoutable> from, NSDictionary<NSString *, id<ReduxyRoutable>> *to) {
        [self didRouteFrom:from to:to.allValues];
    });
}

- (void)unrouteAction:(ReduxyAction)action {
    NSNumber *implicit = action.payload[@"implicit"];
    
    if (!self.routesAutoway && implicit.boolValue) {
        return ;
    }
    
    NSString *path = action.payload[@"path"];
    NSString *fromPath = action.payload[@"from-path"];
    NSString *fromTag = action.payload[@"from-tag"];
    
    NSDictionary *pathInfo = self.paths[path];
    RouterUnroute unroute = pathInfo[@"unroute"];
    
    id<ReduxyRoutable> from = [self findRoutableWithPath:fromPath tag:fromTag];
    if (from) {
        [self removeRoutable:from];
        unroute(from, ^(id<ReduxyRoutable> from) {
            [self didUnrouteFrom:from];
        });
    }
}

#pragma mark - routable tag

- (void)tagRoutable:(id<ReduxyRoutable>)routable value:(id)value {
    NSParameterAssert(routable);
    NSParameterAssert(value);
    
    objc_setAssociatedObject(routable, &routableTageAssoociationKey, value, OBJC_ASSOCIATION_COPY);
}

- (id)tagOfRoutable:(id<ReduxyRoutable>)routable {
    NSParameterAssert(routable);
    
    id r = objc_getAssociatedObject(routable, &routableTageAssoociationKey);
    if (r) {
        return r;
    }
    else {
        NSString *tag = [NSString stringWithFormat:@"%p", routable];
        [self tagRoutable:routable value:tag];
        return tag;
    }
}

#pragma mark - routing tabls

- (void)addRoutable:(id<ReduxyRoutable>)routable {
    [self.routables addObject:routable];
}

- (void)removeRoutable:(id<ReduxyRoutable>)routable {
    [self.routables removeObject:routable];
}

- (id<ReduxyRoutable>)findRoutableWithPath:(NSString *)path tag:(id)tagToFind {
    NSParameterAssert(path);
    NSParameterAssert(tagToFind);
    
    for (id<ReduxyRoutable> routable in self.routables) {
        NSString *tag = [self tagOfRoutable:routable];
        
        if ([routable.path isEqualToString:path] &&
            [tag isEqualToString:tagToFind])
        {
            return routable;
        }
    }
    return nil;
}

#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' will move to parent: %@", [vc path], parent);
}

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' did move to parent: %@", [vc path], parent);
    
    BOOL attached = (parent != nil);
    if (attached) {
        [self didRouteFrom:parent to:@[ vc ]];
    }
    else {
        [self didUnrouteFrom:vc];
    }
}

- (BOOL)didUnrouteFrom:(id<ReduxyRoutable>)from {
    NSParameterAssert(from);
    
    LOG(@"did unroute, from: '%@'", from.path);
    
    NSString *fromTag = [self tagOfRoutable:from];
    BOOL hasFromYet = ([self findRoutableWithPath:from.path tag:fromTag] != nil);
    
    if (hasFromYet) {
        LOG(@"has from '%@' yet", from.path);
        LOG(@"remove routable of path: %@", from.path);
        
        [self removeRoutable:from];
        
        NSString *path = objc_getAssociatedObject(from, &routePathAssoociationKey);
        objc_removeAssociatedObjects(from);
        
        [self.store dispatch:ratype(router.unroute)
                     payload:@{ @"path": path,
                                @"from-path": from.path,
                                @"from-tag": fromTag,
                                @"implicit": @YES,
                                }];
    }
    
    return YES;
}

- (BOOL)didRouteFrom:(id<ReduxyRoutable>)from to:(NSArray<id<ReduxyRoutable>> *)to {
    NSParameterAssert(from);
    NSParameterAssert(to);
    
    LOG(@"did route, from: '%@' to: '%@'", from.path, [to valueForKey:@"path"]);
    
    for (id<ReduxyRoutable> routable in to) {
        NSString *tag = [self tagOfRoutable:routable];
        BOOL hasToAlready = ([self findRoutableWithPath:routable.path tag:tag] != nil);
        if (hasToAlready) {
            LOG(@"routable '%@' is already in routables", routable.path);
        }
        else {
            LOG(@"warning: implicit routing: %@", routable.path);
            
            [self addRoutable:routable];
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
        
        [self routeAction:action];
    }
    else if ([action is:ratype(router.unroute)]) {
        NSString *path = action.payload[@"path"];
        
        LOG(@"router subscriber> unroute action: %@", path);
        
        [self unrouteAction:action];
    }
}

@end
