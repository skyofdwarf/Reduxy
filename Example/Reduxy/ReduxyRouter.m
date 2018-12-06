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


static const NSInteger routePathAssoociationKey = 0;
static const NSInteger routableTagAssoociationKey = 0;
static const NSInteger routableNameAssoociationKey = 0;


#pragma mark - UIViewController (ReduxyRoutable)

@implementation UIViewController (ReduxyRoutable)

- (UIViewController *)vc {
    return self;
}

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

@property (strong, nonatomic) NSMutableDictionary<NSString */*name*/, RouterTargetCreator> *targets;
@property (strong, nonatomic) NSMutableDictionary<NSString */*path*/, id> *paths;

@property (strong, nonatomic) NSMutableSet<id<ReduxyRoutable>> *routables;

@property (strong, nonatomic) NSMutableArray<NSDictionary *> *pathStack;
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
        self.pathStack = @[].mutableCopy;
        
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
        
        [self nameRoutable:routable to:target];
        [self tagRoutable:routable to:tag];
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
                            @"from-tag": fromTag,
                            }
     ];
}

- (void)unrouteFrom:(id<ReduxyRoutable>)from {
    NSString *path = objc_getAssociatedObject(from, &routePathAssoociationKey);
    NSString *fromTag = [self tagOfRoutable:from];
    
    [self.store dispatch:ratype(router.unroute)
                 payload:@{ @"path": path,
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
    NSString *fromTag = action.payload[@"from-tag"];
    NSDictionary *context = action.payload[@"context"];
    NSDictionary *targetTags = action.payload[@"target-tags"];
    
    NSDictionary *pathInfo = self.paths[path];
    
    RouterRoute route = pathInfo[@"route"];
    
    NSMutableDictionary *to = @{}.mutableCopy;
    id<ReduxyRoutable> from = [self findRoutableWithTag:fromTag];
    
    for (NSString *target in targetTags.allKeys) {
        NSString *tag = targetTags[target];
        
        id<ReduxyRoutable> routable = [self findRoutableWithTag:tag];
        if (routable) {
            to[target] = routable;
        }
        else {
            RouterTargetCreator creator = self.targets[target];
            id<ReduxyRoutable> routable = creator(from, context);
            
            to[target] = routable;
            
            [self nameRoutable:routable to:target];
            [self tagRoutable:routable to:tag];
            [self addRoutable:routable];
            
            objc_setAssociatedObject(routable, &routePathAssoociationKey, path, OBJC_ASSOCIATION_COPY);
        }
    }
    
    [self pushPath:@{ @"path": path,
                      @"from-tag": fromTag,
                      @"target-tags": targetTags,
                      }];
    
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
    NSString *fromTag = action.payload[@"from-tag"];
    
    NSDictionary *pathInfo = self.paths[path];
    RouterUnroute unroute = pathInfo[@"unroute"];
    
    id<ReduxyRoutable> from = [self findRoutableWithTag:fromTag];
    if (from) {
        [self removeRoutable:from];
        
        [self popPath:@{ @"path": path,
                          @"from-tag": fromTag }];
        
        unroute(from, ^(id<ReduxyRoutable> from) {
            [self didUnrouteFrom:from];
        });
    }
}

#pragma mark - routable tag

- (void)nameRoutable:(id<ReduxyRoutable>)routable to:(id)value {
    NSParameterAssert(routable);
    NSParameterAssert(value);
    
    objc_setAssociatedObject(routable, &routableNameAssoociationKey, value, OBJC_ASSOCIATION_COPY);
}

- (id)nameOfRoutable:(id<ReduxyRoutable>)routable {
    if (routable) {
        id v = objc_getAssociatedObject(routable, &routableNameAssoociationKey);
        if (v) {
            return v;
        }
        else {
            return routable;
        }
    }
    return nil;
}

- (void)tagRoutable:(id<ReduxyRoutable>)routable to:(id)value {
    NSParameterAssert(routable);
    NSParameterAssert(value);
    
    objc_setAssociatedObject(routable, &routableTagAssoociationKey, value, OBJC_ASSOCIATION_COPY);
}

- (id)tagOfRoutable:(id<ReduxyRoutable>)routable {
    NSParameterAssert(routable);
    
    id r = objc_getAssociatedObject(routable, &routableTagAssoociationKey);
    if (r) {
        return r;
    }
    else {
        NSString *tag = [NSString stringWithFormat:@"%p", routable];
        [self tagRoutable:routable to:tag];
        return tag;
    }
}

#pragma mark - stack

- (void)pushPath:(NSDictionary *)info {
    [self.pathStack addObject:info];
}

- (void)popPath:(NSDictionary *)infoToPop {
    NSString *pathToPop = infoToPop[@"path"];
    NSString *fromTag = infoToPop[@"from-tag"];
    
    __block NSInteger foundIndex = NSNotFound;
    
    [self.pathStack enumerateObjectsWithOptions:NSEnumerationReverse
                                     usingBlock:
     ^(NSDictionary * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
         if ([info[@"path"] isEqualToString:pathToPop]) {
             NSDictionary *targets = info[@"target-tags"];
             
             [targets.allValues enumerateObjectsUsingBlock:^(NSString *tag, NSUInteger idx, BOOL * _Nonnull stop) {
                 if ([tag isEqualToString:fromTag]) {
                     foundIndex = idx;
                     *stop = YES;
                 }
             }];
             
             *stop = (foundIndex != NSNotFound);
         }
     }];
    
    if (foundIndex != NSNotFound) {
        [self.pathStack removeObjectsInRange:NSMakeRange(foundIndex, self.pathStack.count - foundIndex)];
    }
    else {
        NSAssert(NO, @"Not found path to pop from stack");
    }
}

#pragma mark - routables

- (void)addRoutable:(id<ReduxyRoutable>)routable {
    [self.routables addObject:routable];
}

- (void)removeRoutable:(id<ReduxyRoutable>)routable {
    [self.routables removeObject:routable];
}

- (id<ReduxyRoutable>)findRoutableWithTag:(id)tagToFind {
    NSParameterAssert(tagToFind);
    
    for (id<ReduxyRoutable> routable in self.routables) {
        NSString *tag = [self tagOfRoutable:routable];
        
        if ([tag isEqualToString:tagToFind]) {
            return routable;
        }
    }
    return nil;
}

#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' will move to parent: %@", [self nameOfRoutable:vc], [self nameOfRoutable:parent]);
}

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent {
    LOG(@"'%@' did move to parent: %@", [self nameOfRoutable:vc], [self nameOfRoutable:parent]);
    
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
    
    LOG(@"did unroute, from: '%@'", [self nameOfRoutable:from]);
    
    NSString *fromTag = [self tagOfRoutable:from];
    BOOL hasFromYet = ([self findRoutableWithTag:fromTag] != nil);
    
    if (hasFromYet) {
        LOG(@"has from '%@' yet", [self nameOfRoutable:from]);
        LOG(@"remove routable of path: %@", [self nameOfRoutable:from]);
        
        [self removeRoutable:from];
        
        NSString *path = objc_getAssociatedObject(from, &routePathAssoociationKey);
        objc_removeAssociatedObjects(from);
        
        [self.store dispatch:ratype(router.unroute)
                     payload:@{ @"path": path,
                                @"from-tag": fromTag,
                                @"implicit": @YES,
                                }];
    }
    
    return YES;
}

- (BOOL)didRouteFrom:(id<ReduxyRoutable>)from to:(NSArray<id<ReduxyRoutable>> *)to {
    NSParameterAssert(from);
    NSParameterAssert(to);
    
    LOG(@"did route, from: '%@' to: '%@'", [self nameOfRoutable:from], to);
    
    for (id<ReduxyRoutable> routable in to) {
        NSString *tag = [self tagOfRoutable:routable];
        BOOL hasToAlready = ([self findRoutableWithTag:tag] != nil);
        if (hasToAlready) {
            LOG(@"routable '%@' is already in routables", [self nameOfRoutable:routable]);
        }
        else {
            LOG(@"warning: implicit routing: %@", [self nameOfRoutable:routable]);
            
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
