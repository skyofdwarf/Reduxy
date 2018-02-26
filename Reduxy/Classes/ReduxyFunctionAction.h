//
//  ReduxyFunctionAction.h
//  Expecta
//
//  Created by yjkim on 19/02/2018.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"


/*!
 type of actual function of ReduxyFunctionAction and do custom task like `middleware`
 must return `ReduxyAction` function to cancel running task.
 */
typedef ReduxyAction (^ReduxyFunctionActor)(id<ReduxyStore> store, ReduxyDispatch next, ReduxyAction action);

/*!
 the action type used for ReduxyFunctionMiddleware.
 ReduxyFunctionAction is wrapper class for ReduxyFunctionActor function.
 */
@interface ReduxyFunctionAction : NSObject
@property (copy, nonatomic) ReduxyFunctionActor call;

+ (instancetype)newWithActor:(ReduxyFunctionActor)actor;
- (instancetype)initWithActor:(ReduxyFunctionActor)actor;
@end

