//
//  ReduxyTypes.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#ifndef ReduxyTypes_h
#define ReduxyTypes_h




#define REDUXY_ACTION(type, data)\
@{\
  ReduxyActionTypeKey: type,\
  ReduxyActionDataKey: data \
}


#pragma mark - forward declarations of protocols

@protocol ReduxyActionable;
@protocol ReduxyStore;
@protocol ReduxyStoreSubscriber;

@class ReduxyStore;


#pragma mark - types
typedef id<ReduxyActionable> ReduxyAction;
typedef id ReduxyState;

typedef NSString * const ReduxyActionType;



#pragma mark - function types

typedef ReduxyState (^ReduxyReducer)(ReduxyState state, ReduxyAction action);

typedef ReduxyState (^ReduxyGetState)(void);
typedef ReduxyAction (^ReduxyDispatch)(ReduxyAction action);

typedef ReduxyDispatch (^ReduxyTransducer)(ReduxyDispatch next);
typedef ReduxyTransducer (^ReduxyMiddleware)(id<ReduxyStore> store);


#pragma mark - reduxy action key

FOUNDATION_EXTERN NSString * const ReduxyActionTypeKey;
FOUNDATION_EXTERN NSString * const ReduxyActionPayloadKey;

#pragma mark - reduxy error domain

FOUNDATION_EXTERN NSErrorDomain const ReduxyErrorDomain;


#pragma mark - reduxy errors

typedef NS_ENUM(NSUInteger, ReduxyError) {
    ReduxyErrorUnknown = 0,
    ReduxyErrorMultipleDispatching = 100,
};

#pragma mark - reducer helper

FOUNDATION_EXTERN ReduxyReducer ReduxyKeyPathReducerForAction(ReduxyActionType type, NSString *key, id defaultValue);



#pragma mark - middleware helper macro


/**
 utility macro for creating a middleware
 
 maybe you should be call `next(action)` at last line of block to keep chaining of middlewares

 @param store instance of ReduxyStore
 @param next next middleware
 @param action action dispatched
 @param block code block of middleware
 @return block of middleware
 */
#define ReduxyMiddlewareCreateMacro(store, next, action, block) \
^ReduxyTransducer (id<ReduxyStore> store) { \
  return ^ReduxyDispatch (ReduxyDispatch next) { \
    return ^ReduxyAction (ReduxyAction action) { \
      block \
    }; \
  }; \
};


#pragma mark - reduxy protocols

@protocol ReduxyActionable <NSObject>
@required
- (ReduxyActionType)type;
- (BOOL)is:(ReduxyActionType)type;

@optional
- (id)payload;
@end

@protocol ReduxyStoreSubscriber <NSObject>
@required
- (void)reduxyStore:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action;
@end


@protocol ReduxyStore <NSObject>
- (ReduxyState)getState;
- (ReduxyAction)dispatch:(ReduxyAction)action;
- (ReduxyAction)dispatch:(ReduxyActionType)action payload:(id)payload;

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber;
- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber;
@end


#pragma mark - default implementations of ReduxyAction protocol

@interface NSObject (ReduxyAction) <ReduxyActionable>
- (ReduxyActionType)type;
- (id)payload;

- (BOOL)is:(ReduxyActionType)type;
@end

@interface NSString (ReduxyAction) <ReduxyActionable>
- (ReduxyActionType)type;
- (NSString *)payload;
@end

@interface NSDictionary (ReduxyAction) <ReduxyActionable>
- (ReduxyActionType)type;
- (NSDictionary *)payload;
@end


#endif /* ReduxyTypes_h */
