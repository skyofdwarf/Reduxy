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
            NSLog(@"function mw> received action: %@", action.type);
            if ([action isKindOfClass:ReduxyFunctionAction.class]) {
                ReduxyFunctionAction *functionAction = (ReduxyFunctionAction *)action;
                
                NSLog(@"function mw> detected function action, tag: %@", functionAction.tag);
                
                id returnValueOrCanceller = functionAction.call(store, next, action);
                
                next(action);
                
                return returnValueOrCanceller;
            }
            else {
                return next(action);
            }
        };
    };
};
