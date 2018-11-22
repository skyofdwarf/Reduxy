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
- (ReduxyState)state;
@end


@protocol ReduxyRecorder <NSObject>

/**
 records action and current state

 @param action action to record
 @param state current state to record
 @return YES if recorded, else NO
 */
- (BOOL)record:(ReduxyAction)action state:(ReduxyState)state;

- (NSArray<ReduxyRecorderItem> *)items;
- (void)clear;

- (void)save;
- (void)load;
@end


@interface NSDictionary (ReduxyRecorderItem) <ReduxyRecorderItem>
- (ReduxyAction)action;
- (ReduxyState)state;
@end



typedef ReduxyMiddleware (^RecorderMiddleware)(id<ReduxyRecorder> recorder);

FOUNDATION_EXTERN NSString * const ReduxyRecorderItemAction;
FOUNDATION_EXTERN NSString * const ReduxyRecorderItemState;

FOUNDATION_EXTERN RecorderMiddleware ReduxyRecorderMiddlewareWithRecorder;


#endif /* ReduxyRecoderMiddleware_h */
