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
            if ([action isKindOfClass:ReduxyFunctionAction.class]) {
                ReduxyFunctionAction *functionAction = (ReduxyFunctionAction *)action;
                
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
