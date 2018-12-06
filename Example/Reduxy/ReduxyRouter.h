//
//  ReduxyRouter.h
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"
#import "ReduxyRoutable.h"

typedef void (^RouterRouteCompletion)(id<ReduxyRoutable> from, NSDictionary<NSString *, id<ReduxyRoutable>> *to);
typedef void (^RouterUnrouteCompletion)(id<ReduxyRoutable> from);

typedef id<ReduxyRoutable> (^RouterTargetCreator)(id<ReduxyRoutable> from, NSDictionary *context);
typedef void (^RouterRoute)(id<ReduxyRoutable> from, NSDictionary<NSString *, id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion);
typedef void (^RouterUnroute)(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion);


#pragma mark - UIViewController (ReduxyRoutable) <ReduxyRoutable>

@interface UIViewController (ReduxyRoutable) <ReduxyRoutable>
@end



#pragma mark - Router

@interface ReduxyRouter : NSObject
@property (class, strong, nonatomic, readonly) NSString *stateKey;


/**
 routes auto-way action
 */
@property (assign, nonatomic) BOOL routesAutoway;

+ (instancetype)shared;

#pragma mark - store

- (void)attachStore:(id<ReduxyStore>)store;

#pragma mark - routing

- (void)addTarget:(NSString *)name creator:(RouterTargetCreator)creator;
- (void)addPath:(NSString *)path targets:(NSArray<NSString *> *)targets route:(RouterRoute)route unroute:(RouterUnroute)unroute;

- (void)removeTarget:(NSString *)name;
- (void)removePath:(NSString *)path;

- (void)routePath:(NSString *)path from:(id<ReduxyRoutable>)from context:(NSDictionary *)context;
- (void)unroutePath:(NSString *)path from:(id<ReduxyRoutable>)from;
- (void)unrouteFrom:(id<ReduxyRoutable>)from;



#pragma mark - event

- (void)viewController:(UIViewController<ReduxyRoutable> *)vc willMoveToParentViewController:(UIViewController *)parent;
- (void)viewController:(UIViewController<ReduxyRoutable> *)vc didMoveToParentViewController:(UIViewController *)parent;

@end




