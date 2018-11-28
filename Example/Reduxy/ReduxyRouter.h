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
- (NSString *)path;

@optional
- (UIViewController *)vc;
- (UIView *)view;
@end


typedef void (^RouteCompletion)(id<ReduxyRoutable> from, id<ReduxyRoutable> to);
typedef id<ReduxyRoutable> (^RouteAction)(id<ReduxyRoutable> src, id context, RouteCompletion completion);



@interface UIViewController (ReduxyRoutable) <ReduxyRoutable>
@end


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

- (void)setInitialRoutables:(NSArray<id<ReduxyRoutable>> *)routables;

#pragma mark - redux

+ (ReduxyMiddleware)middleware NS_UNAVAILABLE;

- (ReduxyReducerTransducer)reducer;
- (ReduxyReducerTransducer)reducerWithInitialRoutables:(NSArray<id<ReduxyRoutable>> *)vcs;


#pragma mark - routing

- (void)add:(NSString *)path route:(RouteAction)route unroute:(RouteAction)unroute;

- (void)remove:(NSString *)path;

#pragma mark - dispatch un/route

- (void)routePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context;
- (void)unroutePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context;

#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent;
- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent;
    
- (void)willUnrouteForPath:(NSString *)path from:(id<ReduxyRoutable>)from;
- (BOOL)didUnrouteFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to;

- (void)willRouteForPath:(NSString *)path from:(id<ReduxyRoutable>)from;
- (BOOL)didRouteFrom:(id<ReduxyRoutable>)from to:(id<ReduxyRoutable>)to;


@end
