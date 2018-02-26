//
//  ReduxyFunctionMiddleware.m
//  Expecta
//
//  Created by yjkim on 26/02/2018.
//

#import "ReduxyFunctionMiddleware.h"
#import "ReduxyFunctionAction.h"

ReduxyMiddleware const ReduxyFunctionMiddleware = ^ReduxyTransducer (id<ReduxyStore> store) {
    return ^ReduxyDispatch (ReduxyDispatch next) {
        return ^ReduxyAction (ReduxyAction action) {
            NSLog(@"function mw> received action: %@", action);
            if ([action isKindOfClass:ReduxyFunctionAction.class]) {
                NSLog(@"function mw> async action");
                ReduxyFunctionAction *functionAction = (ReduxyFunctionAction *)action;
                
                return functionAction.call(store, next, action);
            }
            else {
                NSLog(@"function mw> normal action");
                return next(action);
            }
        };
    };
};