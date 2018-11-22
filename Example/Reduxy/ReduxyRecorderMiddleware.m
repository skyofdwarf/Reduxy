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
NSString * const ReduxyRecorderItemState = @"state";


RecorderMiddleware ReduxyRecorderMiddlewareWithRecorder = ^ReduxyMiddleware(id<ReduxyRecorder> recorder) {
    return ^ReduxyTransducer (id<ReduxyStore> store) {
        return ^ReduxyDispatch (ReduxyDispatch next) {
            return ^ReduxyAction (ReduxyAction action) {
                LOG(@"recorder mw> record action: %@", action.type);
                
                [recorder record:action state:[store getState]];
                
                return next(action);
            };
        };
    };
};


@implementation NSDictionary (ReduxyRecorderItem)
- (ReduxyAction)action {
    return self[ReduxyRecorderItemAction];
}
- (ReduxyState)state {
    return self[ReduxyRecorderItemState];
}
@end


