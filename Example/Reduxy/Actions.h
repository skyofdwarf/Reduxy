//
//  Actions.h
//  Reduxy_Example
//
//  Created by yjkim on 10/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"
#import <objc/runtime.h>
#import <objc/message.h>



/**
 macro to register keypath to raction

 @param action_type action type to register
 @param comment justcomment
 */
#define raction_add(action_type, ...) [ReduxyActionManager.shared register:@(#action_type)]

/**
macro to register keypath to raction

@param action_type action type to register
@param comment justcomment
*/
#define raction_remove(action_type, ...) [ReduxyActionManager.shared unregister:@(#action_type)]


/**
 returns validated action with type and payload

 @param action_type action type to use
 @param payload payload
 
 @return ReduxyAction
 */
#define raction(type) raction_payload(type, nil)
#define raction_payload(type, p) [ReduxyActionManager.shared actionWithType:@(#type) payload:p]

#define raction_raw(type, p) [ReduxyActionManager.shared actionWithType:type payload:p]


/**
 just convert to NSString *, no validation

 @param type action type
 @return ReduxyActionType
 */
#define raction_nv(type) raction_log(type)
#define raction_log(type) @(#type)

/**
 returns validated action type
 
 @param action_type action type to use
 @param payload paload
 
 @return ReduxyActionType
 */
#define ratype(action_type) [ReduxyActionManager.shared type:@(#action_type)]


/**
 action manager which register action to be used and validate action being used
 */
@interface ReduxyActionManager: NSObject

+ (instancetype)shared;


/**
 register action type

 @param actionType action type to register
 */
- (void)register:(ReduxyActionType)actionType;


/**
 unregister action type

 @param actionType action type to unregister
 */
- (void)unregister:(ReduxyActionType)actionType;


/**
 validate action type and just return the action type

 @param actionType action type to return after validattion
 @return id<ReduxyAction> instance, or throw exception
 */
- (ReduxyActionType)type:(ReduxyActionType)actionType;

/**
 validate action type and just return the action type
 
 @param actionType action type to return after validattion
 @param payload payload of action type
 @return id<ReduxyAction> instance, or throw exception
 */
- (ReduxyAction)actionWithType:(ReduxyActionType)actionType payload:(id)payload;
@end





