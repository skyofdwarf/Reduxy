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

- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer;
- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer ignorableActions:(NSArray<ReduxyActionType> *)ignorableActions;
    
- (BOOL)recordWithAction:(ReduxyAction)action state:(ReduxyState)state;

- (NSArray<ReduxyRecorderItem> *)items;
- (void)clear;

- (void)save;
- (void)load;

@end
