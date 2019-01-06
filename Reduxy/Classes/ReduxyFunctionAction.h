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
typedef id (^ReduxyFunctionActor)(id<ReduxyStore> store, ReduxyDispatch next, ReduxyAction action);

/*!
 the action type used for ReduxyFunctionMiddleware.
 ReduxyFunctionAction is wrapper class for ReduxyFunctionActor function.
 */
@interface ReduxyFunctionAction : NSObject <ReduxyActionable>
@property (copy, nonatomic, readonly) ReduxyFunctionActor call;
@property (copy, nonatomic, readonly) NSString *tag;

+ (instancetype)newWithActor:(ReduxyFunctionActor)actor;
+ (instancetype)newWithActor:(ReduxyFunctionActor)actor tag:(NSString *)tag;

- (instancetype)initWithActor:(ReduxyFunctionActor)actor;
- (instancetype)initWithActor:(ReduxyFunctionActor)actor tag:(NSString *)tag;

@end

