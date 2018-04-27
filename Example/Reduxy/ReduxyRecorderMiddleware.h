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

FOUNDATION_EXTERN RecorderMiddleware createRecorderMiddleware;

FOUNDATION_EXTERN NSString * const ReduxyRecorderItemAction;
FOUNDATION_EXTERN NSString * const ReduxyRecorderItemPrevState;
FOUNDATION_EXTERN NSString * const ReduxyRecorderItemNextState;


#endif /* ReduxyRecoderMiddleware_h */
