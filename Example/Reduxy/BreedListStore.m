//
//  BreedListStore.m
//  Reduxy_Example
//
//  Created by skyofdwarf on 2019. 1. 7..
//  Copyright © 2019년 skyofdwarf. All rights reserved.
//

#import "BreedListStore.h"

static ReduxyMiddleware logger = rmiddleware(store, next, action, {
    LOG(@"logger mw> received action: %@", action);
    return next(action);
});



@implementation BreedListStore

- (instancetype)init {
    ReduxyReducer breedsReducer = [Reduxy reducerForAction:ratype(reload)
                                                   keypath:@"data.breeds"
                                              defaultValue:@{}];
    ReduxyReducer filterReducer = [Reduxy reducerForAction:ratype(filter)
                                                   keypath:@"filter"
                                              defaultValue:@""];
    ReduxyReducer indicatorReducer = [Reduxy reducerForAction:ratype(indicator)
                                                 defaultValue:@NO];
    ReduxyReducer createdAtReducer = [Reduxy reducerForAction:ratype(created)
                                            defaultValueBlock:^{ return [NSDate date]; }];
    
    __unused ReduxyReducer notUsedReducer = [Reduxy reducerForAction:ratype(not.used)
                                                              reduce:^(ReduxyState state, ReduxyActionPayload payload) {
                                                                  return [payload valueForKeyPath:@"not.used"];
                                                              }
                                                   defaultValueBlock:^{ return @"not used"; }];
    
    ReduxyReducer rootReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
        return @{ @"breeds": breedsReducer(state[@"breeds"], action),
                  @"filter": filterReducer(state[@"filter"], action),
                  @"ui": @{ @"indicator": indicatorReducer([state valueForKeyPath:@"ui.indicator"], action),
                            @"help": @NO },
                  @"created_at": createdAtReducer(state[@"created_at"], action),
                  };
    };
    
    self = [super initWithState:rootReducer(nil, nil)
                        reducer:rootReducer
                    middlewares:@[ logger,
                                   ReduxyFunctionMiddleware,
                                   ReduxyMainQueueMiddleware ]
                        actions:@[ ratype(reload),
                                   ratype(filter),
                                   ratype(indicator),
                                   ratype(created),
                                   ]];
    if (self) {
    }
    return self;
}
@end
