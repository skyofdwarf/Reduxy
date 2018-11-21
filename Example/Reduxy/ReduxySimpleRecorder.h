//
//  ReduxySimpleRecorder.h
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyRecorderMiddleware.h"


/**
 ReduxySimpleRecorder
 
 action은 내부적으로 아래 형식으로 저장됨 
 @{
   ReduxyRecorderItemAction: action,
   ReduxyRecorderItemPrevState: state,
   ReduxyRecorderItemNextState: nextState,
 };
 */
@interface ReduxySimpleRecorder : NSObject <ReduxyRecorder>
@property (assign, nonatomic) BOOL enabled;

#pragma mark - constructors

/**
 recorder를 생성한다
 기록할 액션에 대한 결과 state를 같이 기록하기 위해 root-reducer가 필요하다.
 기록을 무시할 액션 목록

 @param rootReducer store의 root-reducer
 @param ignorableActions 기록을 무시할 액션 목록
 @return recorder instance
 */
- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer ignorableActions:(NSArray<ReduxyActionType> *)ignorableActions;

- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer;


#pragma mark - ReduxyRecorder protocol
- (BOOL)record:(ReduxyAction)action state:(ReduxyState)state;

- (NSArray<ReduxyRecorderItem> *)items;
- (void)clear;

- (void)save;
- (void)load;

@end
