//
//  ReduxyRecoder.h
//  Reduxy
//
//  Created by yjkim on 26/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#ifndef ReduxyRecoder_h
#define ReduxyRecoder_h

#import "ReduxyTypes.h"


FOUNDATION_EXTERN ReduxyActionType ReduxyRecorderItemAction;
FOUNDATION_EXTERN ReduxyActionType ReduxyRecorderItemState;


#pragma mark - ReduxyRecoderItem

@protocol ReduxyRecorderItem <NSObject>
- (ReduxyAction)action;
- (ReduxyState)state;
@end


@interface NSDictionary (ReduxyRecorderItem) <ReduxyRecorderItem>
- (ReduxyAction)action;
- (ReduxyState)state;
@end


#pragma mark - ReduxyRecorder

@protocol ReduxyRecorder <NSObject>
/**
 records action and current state

 @param action action to record
 @param state current state to record
 @return YES if recorded, else NO
 */
- (BOOL)record:(ReduxyAction)action state:(ReduxyState)state;

- (NSArray<ReduxyRecorderItem> *)items;

- (void)start;
- (void)stop;

- (void)clear;

- (void)save;
- (void)load;
@end

#pragma mark - ReduxyPlayer

@protocol ReduxyPlayer <NSObject>
- (void)loadItems:(NSArray<id<ReduxyRecorderItem>> *)items dispatch:(ReduxyDispatch)dispatch;

- (NSInteger)length;

- (ReduxyAction)jump:(NSInteger)index;

- (ReduxyAction)prev;
- (ReduxyAction)next;

- (void)reset;
- (void)clear;

@end


#endif /* ReduxyRecoder_h */
