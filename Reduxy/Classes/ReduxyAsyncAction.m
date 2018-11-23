//
//  ReduxyAsyncAction.m
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import "ReduxyAsyncAction.h"


@implementation ReduxyAsyncAction

+ (instancetype)newWithTag:(NSString *)tag actor:(ReduxyAsyncActor)actor {
    return [[ReduxyAsyncAction alloc] initWithTag:tag actor:actor];
}

- (instancetype)initWithTag:(NSString *)tag actor:(ReduxyAsyncActor)actor {
    
    ReduxyFunctionActor functionActor = ^id(id<ReduxyStore> store, ReduxyDispatch next, ReduxyAction action) {
        ReduxyDispatch storeDispatch = ^ReduxyAction(ReduxyAction action) {
            return [store dispatch:action];
        };
        
        return actor(storeDispatch);
    };
    
    self = [super initWithTag:tag actor:functionActor];
    
    if (self) {
    }
    return self;
}

- (NSString *)type {
    return @"ReduxyAsyncAction";
}
@end
