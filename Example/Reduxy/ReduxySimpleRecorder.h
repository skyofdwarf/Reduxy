//
//  ReduxySimpleRecorder.h
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyRecorder.h"


FOUNDATION_EXTERN ReduxyActionType ReduxyPlayerActionJump;
FOUNDATION_EXTERN ReduxyActionType ReduxyPlayerActionStep;


/**
 ReduxySimpleRecorder
 
 action은 내부적으로 아래 형식으로 저장됨 
 @{
   ReduxyRecorderItemAction: action,
   ReduxyRecorderItemPrevState: state,
   ReduxyRecorderItemNextState: nextState,
 };
 */
@interface ReduxySimpleRecorder : NSObject
<
ReduxyRecorder,
ReduxyStoreSubscriber
>
@property (assign, nonatomic, readonly) BOOL recording;


#pragma mark - constructors

/**
 recorder를 생성한다
 기록할 액션에 대한 결과 state를 같이 기록하기 위해 root-reducer가 필요하다.
 기록을 무시할 액션 목록

 @param rootReducer store의 root-reducer
 @param ignorableActions 기록을 무시할 액션 목록
 @return recorder instance
 */
- (instancetype)initWithStore:(id<ReduxyStore>)store actionTypesToIgnore:(NSArray<ReduxyActionType> *)typesToIgnore;

- (instancetype)initWithStore:(id<ReduxyStore>)store;



#pragma mark - ReduxyRecorder protocol
- (BOOL)record:(ReduxyAction)action state:(ReduxyState)state;

- (NSArray<ReduxyRecorderItem> *)items;

- (void)start;
- (void)stop;

- (void)clear;

- (void)save;
- (void)load;

@end
