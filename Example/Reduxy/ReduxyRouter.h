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

- (void)routableDidRoute;

@optional
- (UIViewController *)vc;
- (UIView *)view;
@end


typedef id<ReduxyRoutable> (^RouteAction)(id<ReduxyRoutable> src, id context);
typedef void (^UnrouteAction)(id<ReduxyRoutable> src, id context);


@interface UIViewController (ReduxyRoutable) <ReduxyRoutable>
- (void)routableDidRoute;
@end


#pragma mark - Router

@interface ReduxyRouter : NSObject
@property (class, strong, nonatomic, readonly) NSString *stateKey;

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

- (void)add:(NSString *)path route:(RouteAction)route unroute:(UnrouteAction)unroute;

- (void)remove:(NSString *)path;

#pragma mark - dispatch

- (void)dispatchRoute:(id)payload;
- (void)dispatchUnroute:(id)payload;

#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent;
- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent;
    
- (void)willUnrouteForPath:(NSString *)path from:(id<ReduxyRoutable>)routable;
- (BOOL)didUnroute:(id<ReduxyRoutable>)routable;

- (void)willRouteForPath:(NSString *)path from:(id<ReduxyRoutable>)routable;
- (BOOL)didRoute:(id<ReduxyRoutable>)routable;


@end
