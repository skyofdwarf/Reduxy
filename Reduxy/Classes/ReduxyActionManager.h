//
//  ReduxyActionManager.h
//  Reduxy_Example
//
//  Created by yjkim on 10/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"


/**
 action manager which register action to be used and validate action being used
 */
@interface ReduxyActionManager: NSObject

- (instancetype)initWithActions:(NSArray<ReduxyActionType> *)actions;
- (instancetype)init;

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
 validate action and throw a exception if action is not registered
 
 @param action action to validate
 @return YES if valid
 */
- (BOOL)valid:(ReduxyAction)action;


/**
 validate action and throw a exception if action is not registered
 
 @param action action to validate
 */
- (void)validate:(ReduxyAction)action;

@end





