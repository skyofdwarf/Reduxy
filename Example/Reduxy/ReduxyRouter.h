//
//  ReduxyRouter.h
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"



@protocol ReduxyRoutable <NSObject>
@required
+ (NSString *)path;

@optional
- (UIViewController *)vc;
- (UIView *)view;
@end


typedef void (^RouteCompletion)(id<ReduxyRoutable> dest);
typedef id<ReduxyRoutable> (^RouteAction)(id<ReduxyRoutable> src, id context, RouteCompletion completion);


#pragma mark - Router

@interface ReduxyRouter : NSObject
@property (class, strong, nonatomic, readonly) NSString *stateKey;


/**
 routes by action not state
 */
@property (assign, nonatomic) BOOL routesByAction;

/**
 routes auto-way action. applied only if routesByAction is enabled
 */
@property (assign, nonatomic) BOOL routesAutoway;

+ (instancetype)shared;

#pragma mark - store

- (void)attachStore:(id<ReduxyStore>)store;



#pragma mark - redux

+ (ReduxyMiddleware)middleware NS_UNAVAILABLE;

- (ReduxyReducerTransducer)reducer;
- (ReduxyReducerTransducer)reducerWithInitialRoutables:(NSArray<id<ReduxyRoutable>> *)vcs
                                              forPaths:(NSArray<NSString *> *)paths;


#pragma mark - routing

- (void)add:(NSString *)path route:(RouteAction)route unroute:(RouteAction)unroute;

- (void)remove:(NSString *)path;

#pragma mark - dispatch un/route

- (void)routePath:(NSString *)path context:(NSDictionary *)context;
- (void)unroutePath:(NSString *)path context:(NSDictionary *)context;

#warning not recordable action
- (void)routePath:(NSString *)path context:(NSDictionary *)context completion:(void (^)(void))completion;

#warning not recordable action
- (void)unroutePath:(NSString *)path context:(NSDictionary *)context completion:(void (^)(void))completion;

#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent;
- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent;
    
- (void)willUnrouteForPath:(NSString *)path from:(id<ReduxyRoutable>)routable;
- (BOOL)didUnroute:(id<ReduxyRoutable>)routable;

- (void)willRouteForPath:(NSString *)path from:(id<ReduxyRoutable>)routable;
- (BOOL)didRoute:(id<ReduxyRoutable>)routable;


@end
