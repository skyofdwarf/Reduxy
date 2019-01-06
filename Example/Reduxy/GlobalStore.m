//
//  Store.m
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "GlobalStore.h"

@interface GlobalStore ()
@end

@implementation GlobalStore

+ (GlobalStore *)shared {
    static dispatch_once_t onceToken;
    static GlobalStore *instance;
    
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    
    return instance;
}

+ (ReduxyReducer)createRootReducer {
    ReduxyReducer indicatorReducer = [Reduxy reducerForAction:ratype(indicator) defaultValue:@NO];
    
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        return @{ @"indicator": indicatorReducer(state[@"indicator"], action),
                  };
    };
}

- (instancetype)init {
    ReduxyReducer rootReducer = [self.class createRootReducer];
    
    self = [super initWithState:rootReducer(nil, nil)
                        reducer:rootReducer
                    middlewares:@[ ReduxyFunctionMiddleware,
                                   ReduxyMainQueueMiddleware ]
                        actions:@[ ratype(indicator) ]];
    if (self) {
    }
    
    return self;
}

@end
