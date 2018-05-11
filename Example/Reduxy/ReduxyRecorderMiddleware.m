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


RecorderMiddleware ReduxyRecorderMiddlewareWithRecorder = ^ReduxyMiddleware(id<ReduxyRecorder> recorder) {
    return ^ReduxyTransducer (id<ReduxyStore> store) {
        return ^ReduxyDispatch (ReduxyDispatch next) {
            return ^ReduxyAction (ReduxyAction action) {
                LOG(@"recorder mw> record action: %@", action);
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

@interface RecordableItem()
{
    NSDictionary *_action;
}
//@property (strong, nonatomic) NSDictionary *data;
@end

@implementation RecordableItem
+ (instancetype)newWithType:(ReduxyActionType)type prevState:(ReduxyState)prevState nextState:(ReduxyState)nextState {
    return [[RecordableItem alloc] initWithType:type prevState:prevState nextState:nextState];
}

- (instancetype)initWithType:(ReduxyActionType)type prevState:(ReduxyState)prevState nextState:(ReduxyState)nextState {
    self = [super init];
    if (self) {
        _action = @{};
    }
    return self;
}

- (NSDictionary *)action {
    return _action;
}
@end


