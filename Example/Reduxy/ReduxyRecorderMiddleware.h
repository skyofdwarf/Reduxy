//
//  ReduxyRecoderMiddleware.h
//  Reduxy
//
//  Created by yjkim on 26/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#ifndef ReduxyRecoderMiddleware_h
#define ReduxyRecoderMiddleware_h

#import "ReduxyTypes.h"



@protocol ReduxyRecorderItem <NSObject>
- (ReduxyAction)action;
- (ReduxyState)prevState;
- (ReduxyState)nextState;
@end


@protocol ReduxyRecorder <NSObject>

/**
 action과 state를 기록한다.

 @param action 액션
 @param state 해당 액션의 결과인 state
 @return 기록 성공 시 YES
 */
- (BOOL)recordWithAction:(ReduxyAction)action state:(ReduxyState)state;

- (NSArray<ReduxyRecorderItem> *)items;
- (void)clear;

- (void)save;
- (void)load;
@end


@interface NSDictionary (ReduxyRecorderItem) <ReduxyRecorderItem>
- (ReduxyAction)action;
- (ReduxyState)prevState;
- (ReduxyState)nextState;
@end



typedef ReduxyMiddleware (^RecorderMiddleware)(id<ReduxyRecorder> recorder);

FOUNDATION_EXTERN NSString * const ReduxyRecorderItemAction;
FOUNDATION_EXTERN NSString * const ReduxyRecorderItemPrevState;
FOUNDATION_EXTERN NSString * const ReduxyRecorderItemNextState;

FOUNDATION_EXTERN RecorderMiddleware ReduxyRecorderMiddlewareWithRecorder;



@interface RecordableItem: NSObject
+ (instancetype)newWithType:(ReduxyActionType)type prevState:(ReduxyState)prevState nextState:(ReduxyState)nextState;
@end



#endif /* ReduxyRecoderMiddleware_h */
