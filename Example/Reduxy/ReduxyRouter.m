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



ReduxyActionType ReduxyRouterActionRoute = @"reduxy.action.router.route";
ReduxyActionType ReduxyRouterActionBack = @"reduxy.action.router.back";

NSString * const ReduxyRouterStateKey = @"reduxy.routes";



static selector_block routesSelector = ^NSArray<NSString *> * _Nonnull (ReduxyState state) {
    return state[ReduxyRouterStateKey];
};

static selector_block topRouteSelector = ^NSString * _Nullable (ReduxyState state) {
    NSArray<NSString *> *routes = routesSelector(state);
    return [routes lastObject];
};




@interface ReduxyRouter ()
@property (strong, nonatomic) id<ReduxyStore> store;

@property (strong, nonatomic) NSMutableDictionary<NSString */*path*/, RouteAction> *routes;
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
        self.viewControllers = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

#pragma mark - store

- (void)attachStore:(id<ReduxyStore>)store {
    self.store = store;
}

#pragma mark - routing

- (void)add:(NSString *)path route:(RouteAction)route {
    self.routes[path] = route;
}

- (void)remove:(NSString *)path {
    self.routes[path] = nil;
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

#pragma mark - redux

- (ReduxyMiddleware)middleware {
    
    ReduxyRouter *router = self;
    
    return ReduxyMiddlewareCreateMacro(store, next, action, {
        NSLog(@"router> received action: %@", action);
        if ([action is:ReduxyRouterActionRoute]) {
            [router route:action state:[store getState]];
        }
        
        return next(action);
    });
}


- (ReduxyReducer)reducer {
    return [self reducerWithRootViewController:nil forPath:nil];
}

- (ReduxyReducer)reducerWithRootViewController:(UIViewController *)rvc forPath:(NSString *)path {
    
    NSArray *defaultState = ([self setViewController:rvc forPath:path]?
                             @[ @{ @"path": path } ]:
                             @[]);
    
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:ReduxyRouterActionRoute]) {
            NSLog(@"route> %@, add: %@", state, action.data);
            NSMutableArray *routes = [NSMutableArray arrayWithArray:state];
            
            [routes addObject:action.data];
            return routes.copy;
        }
        else if ([action is:ReduxyRouterActionBack]) {
            NSLog(@"route> %@, remove: %@", state, action.data[@"path"]);
            
            NSMutableArray<NSDictionary *> *routes = [NSMutableArray arrayWithArray:state];
            
            NSString *path = action.data[@"path"];
            
            NSDictionary *lastPathInfo = routes.lastObject;
            NSString *lastPath = lastPathInfo[@"path"];
            
            if ([lastPath isEqualToString:path]) {
                [routes removeLastObject];
                return routes.copy;
            }
            else {
                @throw [NSError errorWithDomain:@"ReduxyRouterDomain"
                                           code:0x00F0
                                       userInfo:@{ NSLocalizedDescriptionKey: @"routes에 path 없는디?" }];
            }
        }
        else {
            return (state? state: defaultState);
        }
    };
}


#pragma mark - private

- (void)route:(ReduxyAction)action state:(ReduxyState)state  {
    NSString *path  = action.data[@"path"];
    NSString *context = action.data[@"context"];
    
    UIViewController *source = [self topViewControllerWithState:state];
    
    [self route:path source:source context:context];
}

- (UIViewController *)topViewControllerWithState:(ReduxyState)state {
    NSDictionary *route = topRouteSelector(state);
    
    return [self viewControllerForPath:route[@"path"]];
}

- (UIViewController *)viewControllerForPath:(NSString *)path {
    return [self.viewControllers objectForKey:path];
}

- (BOOL)setViewController:(UIViewController *)vc forPath:(NSString *)path {
    if (path && vc) {
        [self.viewControllers setObject:vc forKey:path];
        return YES;
    }
    
    return NO;
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
            // removes the path from routes
            [self.viewControllers removeObjectForKey:path];
            
            // dispatches disappearing action to remove top path from state
            [self.store dispatch:@{ @"type": ReduxyRouterActionBack,
                                    @"path": path,
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
