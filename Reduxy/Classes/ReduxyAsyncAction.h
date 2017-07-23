//
//  ReduxyAsyncAction.h
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"

#pragma mark - middleware

/*! 
 supports ReduxyAsyncAction instance for action argument of dispatch function to asynchronous action.
 */
FOUNDATION_EXPORT ReduxyMiddleware const ReduxyAsyncActionMiddleware;


#pragma mark - ReduxyAsyncAction

/*!
 used to cancel async task.
 dispatch function returns ReduxyAsyncActionCanceller function as a result of dispatching ReduxyAsyncAction action.
 */
typedef void (^ReduxyAsyncActionCanceller)();

/*!
 implemented to do a async task.
 must return ReduxyAsyncActionCanceller function to cancel running task.
 */
typedef ReduxyAsyncActionCanceller (^ReduxyAsyncActor)(ReduxyDispatch storeDispatch, ReduxyGetState getState);

/*!
 the action type used as a action for ReduxyAsyncActionMiddleware.
 ReduxyAsyncAction is wrapper of ReduxyAsyncActor function. 
 */
@interface ReduxyAsyncAction: NSObject
@property (copy, nonatomic) ReduxyAsyncActor call;

+ (instancetype)newWithActor:(ReduxyAsyncActor)actor;
- (instancetype)initWithActor:(ReduxyAsyncActor)actor;
@end


