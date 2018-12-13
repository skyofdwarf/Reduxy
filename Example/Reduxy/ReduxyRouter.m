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

- (ReduxyReducer)reducer {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:ratype(router.route)]) {
            NSString *path = action.payload[@"path"];
            NSAssert(path, @"No path to route in payload of action");
            if (path) {
                NSMutableArray *mstate = [NSMutableArray arrayWithArray:(state ?: @[])];
                [mstate addObject:action.payload];
                
                return mstate.copy;
            }
        }
        
        if ([action is:ratype(router.unroute)]) {
            NSString *pathToUnroute = action.payload[@"path"];
            NSAssert(pathToUnroute, @"No path to unroute in payload of action");
            if (pathToUnroute) {
                NSMutableArray *mstate = [NSMutableArray arrayWithArray:(state ?: @[])];
                
                __block NSInteger foundIndex = NSNotFound;
                
                [mstate enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:
                 ^(NSDictionary  * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
                     if ([info[@"path"] isEqualToString:pathToUnroute]) {
                         foundIndex = idx;
                         *stop = YES;
                     }
                 }];
                
                if (foundIndex != NSNotFound) {
                    [mstate removeObjectsInRange:NSMakeRange(foundIndex, mstate.count - foundIndex)];
                    return mstate.copy;
                }
                else {
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                                   reason:[NSString stringWithFormat:@"No path '%@', to unroute in state", pathToUnroute]
                                                 userInfo:nil];
                }
            }
        }
        
        return (state? state: @[]);
    };
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

- (NSDictionary *)generateTagsForTargets:(NSArray<NSString *> *)targets {
    NSMutableDictionary *targetTags = @{}.mutableCopy;
    
    for (NSString *target in targets) {
        NSTimeInterval ti = [NSDate timeIntervalSinceReferenceDate];
        NSString *tag = [NSString stringWithFormat:@"%@-%f", target, ti];
        
        targetTags[target] = tag;
    }
    
    return targetTags.copy;
}

- (void)startWithPath:(NSString *)path {
    NSDictionary *pathInfo = self.paths[path];
    NSArray<NSString *> *targets = pathInfo[@"targets"];
    NSMutableDictionary *tags = @{}.mutableCopy;
    
    for (NSString *target in targets) {
        tags[target] = [NSString stringWithFormat:@"%@-main", target];
    }
    
    [self routePath:path from:nil context:nil tags:tags.copy];
}

- (void)routePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context {
    [self routePath:path from:from context:context tags:@{}];
}

- (void)routePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context tags:(NSDictionary *)predefinedTags {
    NSDictionary *pathInfo = self.paths[path];
    NSArray<NSString *> *targets = pathInfo[@"targets"];
    NSString *fromTag = [self tagOfRoutable:from];
    
    NSDictionary *tags = [self generateTagsForTargets:targets];
    if (predefinedTags) {
        NSMutableDictionary *mtags = tags.mutableCopy;
        [mtags addEntriesFromDictionary:predefinedTags];
        
        tags = mtags.copy;
    }
    
    [self.store dispatch:ratype(router.route)
                 payload:@{ @"path": path,
                            @"from-tag": fromTag ?: @"",
                            @"context": context ?: @{},
                            @"targets": @{ @"names": targets,
                                           @"tags": tags,
                                           },
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
    
    [self unroutePath:path from:from];
}

#pragma mark - route payload

- (void)routePayload:(NSDictionary *)payload {
    NSString *path = payload[@"path"];
    NSString *fromTag = payload[@"from-tag"];
    NSDictionary *context = payload[@"context"];
    NSArray *targets = [payload valueForKeyPath:@"targets.names"];
    NSDictionary *targetTags = [payload valueForKeyPath:@"targets.tags"];
    
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
            
            objc_setAssociatedObject(routable, &routePathAssoociationKey, path, OBJC_ASSOCIATION_COPY);
        }
    }
    
    [self pushPath:@{ @"path": path,
                      @"from-tag": fromTag ?: @"",
                      @"targets": @{ @"names": targets,
                                     @"tags": targetTags,
                                     @"routables": to.copy
                                    },
                      }];
    
    route(from, to, context, ^(id<ReduxyRoutable> from, NSDictionary<NSString *, id<ReduxyRoutable>> *to) {
        [self didRouteFrom:from to:to.allValues];
    });
}

- (void)unroutePayload:(NSDictionary *)payload {
    NSString *path = payload[@"path"];
    NSArray<NSString *> *targets = [payload valueForKeyPath:@"targets.names"];
    NSDictionary *targetTags = [payload valueForKeyPath:@"targets.tags"];
    
    NSString *target = targets.lastObject;
    NSString *targetTag = targetTags[target];
    
    NSDictionary *pathInfo = self.paths[path];
    RouterUnroute unroute = pathInfo[@"unroute"];
    
    id<ReduxyRoutable> from = [self findRoutableWithTag:targetTag];
    if (from) {
        [self popPath:@{ @"path": path,
                         @"from-tag": targetTag }];
        
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
    if (!routable) {
        return nil;
    }
    
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
     ^(NSDictionary * _Nonnull info, NSUInteger stackIndex, BOOL * _Nonnull stop) {
         if ([info[@"path"] isEqualToString:pathToPop]) {
             NSDictionary *targets = [info valueForKeyPath:@"targets.tags"];
             
             if ([targets.allValues containsObject:fromTag]) {
                 foundIndex = stackIndex;
                 *stop = YES;
             }
         }
     }];
    
    if (foundIndex != NSNotFound) {
        [self.pathStack removeObjectsInRange:NSMakeRange(foundIndex, self.pathStack.count - foundIndex)];
    }
    else {
        NSAssert(NO, @"Not found path to pop from stack");
    }
}

- (id<ReduxyRoutable>)findRoutableWithTag:(id)tagToFind {
    if (!tagToFind) {
        return nil;
    }
    
    for (NSDictionary *path in self.pathStack) {
        NSDictionary *tags = [path valueForKeyPath:@"targets.tags"];
        
        if ([tags.allValues containsObject:tagToFind]) {
            
        }
        
        NSString *foundTarget = nil;
        
        for (NSString *target in tags) {
            if ([tags[target] isEqualToString:tagToFind]) {
                foundTarget = target;
                break ;
            }
        }
        
        if (foundTarget) {
            NSDictionary *routables = [path valueForKeyPath:@"targets.routables"];
            return routables[foundTarget];
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
        
        NSString *path = objc_getAssociatedObject(from, &routePathAssoociationKey);
        objc_removeAssociatedObjects(from);
        
        [self popPath:@{ @"path": path,
                         @"from-tag": fromTag }];
        
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
        }
    }
    
    return YES;
}

#pragma mark - ReduxyStoreSubscriber

- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    LOG(@"action: %@, state: %@", action, state);
    
    [self processRouteState:state];
}

- (void)processRouteState:(ReduxyState)state {
    
    NSArray *pathsInRouter = self.pathStack;
    NSArray *pathsInState = [state valueForKeyPath:@"router.routes"];
    
    if (pathsInState.count > pathsInRouter.count) {
        // route
        NSDictionary *pathToRoute = pathsInState.lastObject;
        
        [self routePayload:pathToRoute];
        
    }
    else if (pathsInState.count < pathsInRouter.count) {
        // unroute
        NSDictionary *pathToUnroute = pathsInRouter.lastObject;
        
        [self unroutePayload:pathToUnroute];
    }
}

@end
