//
//  ReduxyPlayerMiddleware.m
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxyPlayerMiddleware.h"


/// replay action in middleware, recover state in reducer
ReduxyActionType ReduxyPlayerActionJump = @"reduxy.mw.player.jump";

/// replay action, do not recever state
ReduxyActionType ReduxyPlayerActionStep = @"reduxy.mw.player.step";


ReduxyMiddleware ReduxyPlayerMiddleware = ^ReduxyTransducer (id<ReduxyStore> store) {
    return ^ReduxyDispatch (ReduxyDispatch next) {
        return ^ReduxyAction (ReduxyAction action) {
            if ([action is:ReduxyPlayerActionJump]) {
                LOG(@"player mw> player action: %@", action.type);
                
                id<ReduxyRecorderItem> item = action.payload;
                
                return next(item.action);
            }
            else if ([action is:ReduxyPlayerActionStep]) {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:@"TODO: not implemented yet"
                                             userInfo:action.payload];
            }
            else {
                return next(action);
            }
        };
    };
};

ReduxyReducerTransducer ReduxyPlayerReducer = ^ReduxyReducer (ReduxyReducer next) {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:ReduxyPlayerActionJump]) {
            id<ReduxyRecorderItem> item = action.payload;
            return item.state;
        }
        else {
            return next(state, action);
        }
    };
};
        
