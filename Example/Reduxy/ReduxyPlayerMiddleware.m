//
//  ReduxyPlayerMiddleware.m
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxyPlayerMiddleware.h"


ReduxyActionType ReduxyPlayerActionJump = @"reduxy.action.player.jump";


ReduxyMiddleware ReduxyPlayerMiddleware = ^ReduxyTransducer (id<ReduxyStore> store) {
    NSLog(@"player> 1");
    return ^ReduxyDispatch (ReduxyDispatch next) {
        NSLog(@"player> 2");
        return ^ReduxyAction (ReduxyAction action) {
            if ([action is:ReduxyPlayerActionJump]) {
                id<ReduxyRecorderItem> item = action.data[ReduxyActionDataKey];
                
                next(action);
                return next(item.action);
            }
            else {
                return next(action);
            }
        };
    };
};



ReduxyReducer (^ReduxyPlayerReducerWithRootReducer)(ReduxyReducer) = ^ReduxyReducer(ReduxyReducer next) {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:ReduxyPlayerActionJump]) {
            id<ReduxyRecorderItem> item = action.data[ReduxyActionDataKey];
            
            NSLog(@"player item: %@", item);
            
            return item.nextState;
        }
        else {
            return next(state, action);
        }
    };
};
