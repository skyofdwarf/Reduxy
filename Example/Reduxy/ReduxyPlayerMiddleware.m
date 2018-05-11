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
                id<ReduxyRecorderItem> item = action.data[ReduxyActionDataKey];
                
                return next(item.action);
            }
            else {
                return next(action);
            }
        };
    };
};

