//
//  ReduxyTypes.m
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"


NSErrorDomain const ReduxyErrorDomain = @"ReduxyErrorDomain";

ReduxyMiddleware ReduxyMiddlewareCreate(ReduxyMiddlewareBlock block) {
    return ^ReduxyTransducer (ReduxyDispatch storeDispatch, ReduxyGetState getState) {
        return ^ReduxyDispatch (ReduxyDispatch nextDispatch) {
            return ^ReduxyAction (ReduxyAction action) {
                return block(storeDispatch, nextDispatch, getState, action);
            };
        };
    };
}
