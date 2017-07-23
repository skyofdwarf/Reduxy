//
//  ReduxyAsyncAction.m
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import "ReduxyAsyncAction.h"


#pragma mark - middleware

ReduxyMiddleware const ReduxyAsyncActionMiddleware = ^ReduxyTransducer (ReduxyDispatch storeDispatch, ReduxyGetState getState) {
    return ^ReduxyDispatch (ReduxyDispatch nextDispatch) {
        return ^ReduxyAction (ReduxyAction action) {
            NSLog(@"async> received action: %@", action);
            if ([action isKindOfClass:ReduxyAsyncAction.class]) {
                NSLog(@"async> async action");
                ReduxyAsyncAction *functionAction = (ReduxyAsyncAction *)action;
                return functionAction.call(storeDispatch, getState);
            }
            else {
                NSLog(@"async> normal action");
                return nextDispatch(action);
            }
        };
    };
};


#pragma mark - ReduxyAsyncAction

@implementation ReduxyAsyncAction
+ (instancetype)newWithActor:(ReduxyAsyncActor)actor {
    return [[ReduxyAsyncAction alloc] initWithActor:actor];
}

- (instancetype)initWithActor:(ReduxyAsyncActor)actor {
    self = [super init];
    if (self) {
        self.call = actor;
    }
    return self;
}
@end

