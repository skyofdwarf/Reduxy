//
//  ReduxyTypes.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#ifndef ReduxyTypes_h
#define ReduxyTypes_h


/// reduxy data types
typedef id ReduxyAction;
typedef id ReduxyState;


/// reduxy function types
typedef ReduxyState (^ReduxyReducer)(ReduxyState state, ReduxyAction action);

typedef ReduxyState (^ReduxyGetState)();
typedef ReduxyAction (^ReduxyDispatch)(ReduxyAction action);

typedef ReduxyDispatch (^ReduxyTransducer)(ReduxyDispatch nextDispatch);
typedef ReduxyTransducer (^ReduxyMiddleware)(ReduxyDispatch storeDispatch, ReduxyGetState getState);


/// reduxy errors
typedef NS_ENUM(NSUInteger, ReduxyError) {
    ReduxyErrorUnknown = 0,
    ReduxyErrorMultipleDispatching = 100,
};

FOUNDATION_EXPORT NSErrorDomain const ReduxyErrorDomain;

/// reduxy middleware
typedef ReduxyAction (^ReduxyMiddlewareBlock)(ReduxyDispatch storeDispatch, ReduxyDispatch nextDispatch, ReduxyGetState getState, ReduxyAction action);

FOUNDATION_EXPORT ReduxyMiddleware ReduxyMiddlewareCreate(ReduxyMiddlewareBlock block);

/// middleware helper macro
#define ReduxyMiddlewareCreateMacro(block) \
^ReduxyTransducer (ReduxyDispatch storeDispatch, ReduxyGetState getState) { \
    return ^ReduxyDispatch (ReduxyDispatch nextDispatch) { \
        return ^ReduxyAction (ReduxyAction action) { \
            block \
        }; \
    }; \
};



#endif /* ReduxyTypes_h */
