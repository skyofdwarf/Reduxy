//
//  ReduxyAsyncAction.h
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import <Foundation/Foundation.h>
#import "ReduxyFunctionAction.h"


/*!
 type for cancelling a task.
 ReduxyFunctionMiddleware returns ReduxyAsyncActionCanceller function as a result of dispatching ReduxyAsyncAction action.
 */
typedef void (^ReduxyAsyncActionCanceller)(void);


/*!
 type for async task.
 must return ReduxyAsyncActionCanceller function to cancel running task.
 */
typedef ReduxyAsyncActionCanceller (^ReduxyAsyncActor)(ReduxyDispatch storeDispatch);


/*!
 the action type used as a action for ReduxyFunctionMiddleware.
 ReduxyAsyncAction is wrapper of ReduxyAsyncActor function.
 */
@interface ReduxyAsyncAction : ReduxyFunctionAction

+ (instancetype)newWithActor:(ReduxyAsyncActor)actor;
+ (instancetype)newWithActor:(ReduxyAsyncActor)actor tag:(NSString *)tag;

- (instancetype)initWithActor:(ReduxyAsyncActor)actor;
- (instancetype)initWithActor:(ReduxyAsyncActor)actor tag:(NSString *)tag;
@end

