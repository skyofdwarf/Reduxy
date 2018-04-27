//
//  ReduxyRecorder.h
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyRecorderMiddleware.h"


@interface ReduxyRecorder : NSObject <ReduxyRecorder>
@property (assign, nonatomic) BOOL enabled;

- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer;
- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer ignorableActins:(NSArray<ReduxyActionType> *)ignorableActions;
    
- (BOOL)recordWithAction:(ReduxyAction)action state:(ReduxyState)state;

- (NSArray<ReduxyRecorderItem> *)items;
- (void)clear;

- (void)save;
- (void)load;

@end
