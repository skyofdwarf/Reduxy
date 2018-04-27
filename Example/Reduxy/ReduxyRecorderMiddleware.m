//
//  ReduxyRecoderMiddleware.m
//  Reduxy_Example
//
//  Created by yjkim on 26/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyRecorderMiddleware.h"


NSString * const ReduxyRecorderItemAction = @"action";
NSString * const ReduxyRecorderItemPrevState = @"prevState";
NSString * const ReduxyRecorderItemNextState = @"nextState";


RecorderMiddleware createRecorderMiddleware = ^ReduxyMiddleware(id<ReduxyRecorder> recorder) {
    return ^ReduxyTransducer (id<ReduxyStore> store) {
        NSLog(@"recorder mw> 1");
        return ^ReduxyDispatch (ReduxyDispatch next) {
            NSLog(@"recorder mw> 2");
            return ^ReduxyAction (ReduxyAction action) {
                NSLog(@"recorder mw> record action: %@", action);
                [recorder recordWithAction:action state:[store getState]];
                
                return next(action);
            };
        };
    };
};


@implementation NSDictionary (ReduxyRecorderItem)
- (ReduxyAction)action {
    return self[ReduxyRecorderItemAction];
}
- (ReduxyState)prevState {
    return self[ReduxyRecorderItemPrevState];
}
- (ReduxyState)nextState {
    return self[ReduxyRecorderItemNextState];
}
@end

