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

 @param keypath keypath to register
 @param comment justcomment
 */
#define raction_add(keypath, ...) [raction register:@(#keypath)]


/**
 macro to expand action keypath

 @param keypath keypath to expand
 @return ReduxyActinType instance expanded 
 */
#define raction_x(keypath) [raction expand:@(#keypath)]



//FOUNDATION_EXTERN ReduxyActionType ReduxyActionBreedListFetched;
//FOUNDATION_EXTERN ReduxyActionType ReduxyActionBreedListFiltered;
//FOUNDATION_EXTERN ReduxyActionType ReduxyActionRandomDogFetched;
//
//FOUNDATION_EXTERN ReduxyActionType ReduxyActionReload;
//FOUNDATION_EXTERN ReduxyActionType ReduxyActionStartIndicator;
//FOUNDATION_EXTERN ReduxyActionType ReduxyActionStopIndicator;




@interface raction: NSObject
+ (void)register:(NSString *)keypath;

+ (ReduxyActionType)expand:(NSString *)keypath;
@end





