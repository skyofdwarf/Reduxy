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


NSString * const ReduxyRouterStateKey = @"reduxy.routes";



static selector_block routesSelector = ^NSArray<NSString *> * _Nonnull (ReduxyState state) {
    return state[ReduxyRouterStateKey];
};

static selector_block topRouteSelector = ^NSString * _Nullable (ReduxyState state) {
    NSArray<NSString *> *routes = routesSelector(state);
    return [routes lastObject];
};



#pragma mark - ReduxyRouter


@interface ReduxyRouter ()
@property (strong, nonatomic) id<ReduxyStore> store;

@property (strong, nonatomic) NSMutableDictionary<NSString */*path*/, RouteAction> *routes;
@property (strong, nonatomic) NSMutableDictionary<NSString */*path*/, RouteAction> *unroutes;
@property (strong, nonatomic) NSMapTable<NSString */*path*/, UIViewController */*vc*/> *viewControllers;

@end

@implementation ReduxyRouter

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
        self.viewControllers = [NSMapTable strongToWeakObjectsMapTable];
        
        raction_add(router.route);
        raction_add(router.unroute);
    }
    return self;
}

#pragma mark - store

- (void)attachStore:(id<ReduxyStore>)store {
    self.store = store;
}

#pragma mark - routing

- (void)add:(NSString *)path route:(RouteAction)route {
    //self.routes[path] = route;
    [self add:path route:route unroute:nil];
}

- (void)add:(NSString *)path route:(RouteAction)route unroute:(RouteAction)unroute {
    self.routes[path] = route;
    self.unroutes[path] = unroute;
}

- (void)remove:(NSString *)path {
    self.routes[path] = nil;
    self.unroutes[path] = nil;
}

- (void)route:(NSString *)path source:(UIViewController *)source context:(id)context {
    RouteAction route = self.routes[path];
    if (route) {
        UIViewController *dest = route(source, context);
        
        if (dest) {
            [self setViewController:dest forPath:path];
        }
    }
}

- (void)unroute:(NSString *)path source:(UIViewController *)source {
    if (!source) {
        return ;
    }
    
    RouteAction unroute = self.unroutes[path];
    if (unroute) {
        // at first, remove a vc of the path to prevent auto dispatching unroute action from -[viewController:willMoveToParentViewController:]
        [self setViewController:nil forPath:path];
        
        // do manual unroute
        unroute(source, nil);
    }
}

#pragma mark - redux

- (ReduxyMiddleware)middleware {
    
    ReduxyRouter *router = self;
    
    return ReduxyMiddlewareCreateMacro(store, next, action, {
        LOG(@"router> received action: %@", action);
        
        if ([action is:raction_x(router.route)]) {
            [router route:action state:[store getState]];
        }
        else if ([action is:raction_x(router.unroute)]) {
            [router unroute:action state:[store getState]];
        }
        
        return next(action);
    });
}


- (ReduxyReducer)reducer {
    return [self reducerWithInitialViewControllers:@[] forPaths:@[]];
}

- (ReduxyReducer)reducerWithInitialViewControllers:(NSArray<UIViewController *> *)vcs forPaths:(NSArray<NSString *> *)paths {
    // builds root routing state
    NSMutableArray *defaultState = @[].mutableCopy;
    for (NSInteger index = 0; index < paths.count; ++index) {
        NSString *path = paths[index];
        UIViewController *vc = vcs[index];
        
        [self setViewController:vc forPath:path];
        
        [defaultState addObject:@{ @"path": path }];
    }
    
    // returns a reducer for route state
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:raction_x(router.route)]) {
            LOG(@"route> %@, add: %@", state, action.data);
            NSMutableArray *routes = [NSMutableArray arrayWithArray:state];
            
            [routes addObject:action.data];
            return routes.copy;
        }
        else if ([action is:raction_x(router.unroute)]) {
            LOG(@"route> %@, remove: %@", state, action.data[@"path"]);
            
            NSMutableArray<NSDictionary *> *routes = [NSMutableArray arrayWithArray:state];
            
            NSString *pathToPop = action.data[@"path"];
            
            NSDictionary *topPathInfo = routes.lastObject;
            NSString *topPath = topPathInfo[@"path"];
            
            LOG(@"route reducer> will pop the path: %@", pathToPop);
            if ([topPath isEqualToString:pathToPop]) {
                LOG(@"route reducer> pop the path: %@", pathToPop);
                [routes removeLastObject];
                return routes.copy;
            }
            else {
                LOG(@"route reducer> not found the path: %@", pathToPop);
            }
        }
        
        // else
        return (state? state: defaultState);
    };
}


#pragma mark - private

- (void)route:(ReduxyAction)action state:(ReduxyState)state  {
    NSString *path  = action.data[@"path"];
    NSString *breed = action.data[@"breed"];
    
    UIViewController *source = [self topViewControllerWithState:state];
    
    [self route:path source:source context:breed];
}

- (void)unroute:(ReduxyAction)action state:(ReduxyState)state  {
    NSString *path  = action.data[@"path"];
    
    UIViewController *source = [self topViewControllerWithState:state];
    
    [self unroute:path source:source];
}

- (UIViewController *)topViewControllerWithState:(ReduxyState)state {
    NSDictionary *route = topRouteSelector(state);
    
    return [self viewControllerForPath:route[@"path"]];
}

- (UIViewController *)viewControllerForPath:(NSString *)path {
    return [self.viewControllers objectForKey:path];
}

- (void)setViewController:(UIViewController *)vc forPath:(NSString *)path {
    if (vc) {
        [self.viewControllers setObject:vc forKey:path];
    }
    else {
        [self.viewControllers removeObjectForKey:path];
    }
}

- (NSString *)pathForViewController:(UIViewController *)vc {
    for (NSString *path in self.viewControllers) {
        UIViewController *value = [self.viewControllers objectForKey:path];
        
        if ([vc isEqual:value]) {
            return path;
        }
    }
    return nil;
}

#pragma mark - event

- (void)viewController:(UIViewController *)vc willMoveToParentViewController:(UIViewController *)parent {
    BOOL detached = (parent == nil);
    if (detached) {
        NSString *path = [self pathForViewController:vc];
        if (path) {
            // if the path isn't unrouted manually(navigation back button or interactive pop gesture),
            // we dispatch unroute action at here to synchronize routing states.
            
            // removes the path from routes
            [self setViewController:nil forPath:path];
            
            // dispatches unroute action to remove top path from state
            [self.store dispatch:@{ @"type": raction_x(router.unroute),
                                    @"path": path
                                    }];
        }
    }
    else {
        
    }
}


#if DEBUG

- (NSMapTable<NSString *, UIViewController *> *)vcs {
    return self.viewControllers;
}

#endif

@end
