//
//  ReduxyRouter.m
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxyRouter.h"


@interface ReduxyRouter ()
@property (strong, nonatomic) NSMutableDictionary<NSString *, RouteAction> *routes;
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
    }
    return self;
}

- (void)add:(NSString *)path route:(RouteAction)route {
    self.routes[path] = route;
}

- (void)remove:(NSString *)path {
    self.routes[path] = nil;
}

- (void)route:(NSString *)path {
    RouteAction route = self.routes[path];
    if (route) {
        route(nil, nil);
    }
}


@end
