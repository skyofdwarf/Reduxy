//
//  ReduxyMainQueueMiddleware.m
//  Reduxy
//
//  Created by skyofdwarf on 2019. 1. 5..
//

#import "ReduxyMainQueueMiddleware.h"

ReduxyMiddleware const ReduxyMainQueueMiddleware = rmiddleware(store, next, action, {
    if ([NSThread isMainThread]) {
        return next(action);
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            next(action);
        });
        return action;
    }
});
