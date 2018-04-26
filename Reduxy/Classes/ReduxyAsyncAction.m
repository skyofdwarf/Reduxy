//
//  ReduxyAsyncAction.m
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import "ReduxyAsyncAction.h"


@implementation ReduxyAsyncAction
+ (instancetype)newWithActor:(ReduxyAsyncActor)actor {
    return [[ReduxyAsyncAction alloc] initWithActor:actor];
}

- (instancetype)initWithActor:(ReduxyAsyncActor)actor {
    self = [super init];
    if (self) {
        self.call = ^id (id<ReduxyStore> store, ReduxyDispatch next, ReduxyAction action) {
            ReduxyDispatch storeDispatch = ^ReduxyAction(ReduxyAction action) {
                return [store dispatch:action];
            };
            
            return actor(storeDispatch);
        };
    }
    return self;
}

- (NSString *)type {
    return @"ReduxyAsyncAction";
}
@end
