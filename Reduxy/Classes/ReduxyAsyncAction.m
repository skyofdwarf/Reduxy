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

+ (instancetype)newWithActor:(ReduxyAsyncActor)actor tag:(NSString *)tag {
    return [[ReduxyAsyncAction alloc] initWithActor:actor tag:tag];
}

- (instancetype)initWithActor:(ReduxyAsyncActor)actor {
    return [self initWithActor:actor tag:@"untagged"];
}

- (instancetype)initWithActor:(ReduxyAsyncActor)actor tag:(NSString *)tag {
    
    ReduxyFunctionActor functionActor = ^id(id<ReduxyStore> store, ReduxyDispatch next, ReduxyAction action) {
        ReduxyDispatch storeDispatch = ^ReduxyAction(ReduxyAction action) {
            return [store dispatch:action];
        };
        
        return actor(storeDispatch);
    };
    
    self = [super initWithActor:functionActor tag:tag];
    
    if (self) {
    }
    return self;
}

- (NSString *)type {
    return @"ReduxyAsyncAction";
}
@end
