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
    return ^ReduxyDispatch (ReduxyDispatch next) {
        return ^ReduxyAction (ReduxyAction action) {
            if ([action is:ReduxyPlayerActionJump]) {
                LOG(@"player mw> player action: %@", action.type);
                
                id<ReduxyRecorderItem> item = action.payload;
                
                return next(item.action);
            }
            else {
                return next(action);
            }
        };
    };
};

