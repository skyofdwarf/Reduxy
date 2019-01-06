//
//  ReduxyMainQueueMiddleware.h
//  Reduxy
//
//  Created by skyofdwarf on 2019. 1. 5..
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"


/**
 middleware to dispatch a action in main queue
 
 basically, it's assumed that action is dispatched in main queue.
 but if you can not be sure that, you may add this middleware at end of chain of middlewares.
 
 @ref ReduxyFunctionAction
 */
FOUNDATION_EXTERN ReduxyMiddleware const ReduxyMainQueueMiddleware;
