//
//  ReduxyRouter.h
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"


#pragma mark - actions

#define ReduxyRouterActionRoute  (raction_x(router.route))
#define ReduxyRouterActionBack   (raction_x(router.back))



FOUNDATION_EXTERN NSString * const ReduxyRouterStateKey;

typedef UIViewController * (^RouteAction)(UIViewController *src, id context);



#pragma mark - Router

@interface ReduxyRouter : NSObject
@property (strong, nonatomic, readonly) id<ReduxyStore> store;

+ (instancetype)shared;


#pragma mark - store

- (void)attachStore:(id<ReduxyStore>)store;


#pragma mark - redux

- (ReduxyMiddleware)middleware;

- (ReduxyReducer)reducer;
- (ReduxyReducer)reducerWithInitialViewControllers:(NSArray<UIViewController *> *)vcs
                                          forPaths:(NSArray<NSString *> *)paths;


#pragma mark - routing

- (void)add:(NSString *)path route:(RouteAction)route;
- (void)add:(NSString *)path route:(RouteAction)route unroute:(RouteAction)unroute;

- (void)remove:(NSString *)path;

- (void)route:(NSString *)path source:(UIViewController *)source context:(id)context;



#pragma mark - event

- (void)viewController:(UIViewController *)vc willMoveToParentViewController:(UIViewController *)parent;

#if DEBUG

- (NSMapTable<NSString *, UIViewController *> *)vcs;

#endif

@end
