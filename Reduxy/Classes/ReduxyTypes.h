//
//  ReduxyTypes.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#ifndef ReduxyTypes_h
#define ReduxyTypes_h


#pragma mark - forward declarations of protocols

@protocol ReduxyActionable;
@protocol ReduxyStore;
@protocol ReduxyStoreSubscriber;

#pragma mark - types

typedef id<ReduxyActionable> ReduxyAction;
typedef id ReduxyState;

typedef NSString * const ReduxyActionType;
typedef id ReduxyActionPayload;


#pragma mark - function types

typedef ReduxyState (^ReduxyReducer)(ReduxyState state, ReduxyAction action);
typedef ReduxyReducer (^ReduxyReducerTransducer)(ReduxyReducer next);

typedef ReduxyState (^ReduxyGetState)(void);
typedef ReduxyAction (^ReduxyDispatch)(ReduxyAction action);

typedef ReduxyDispatch (^ReduxyTransducer)(ReduxyDispatch next);
typedef ReduxyTransducer (^ReduxyMiddleware)(id<ReduxyStore> store);

/**
 regular selector, no computations
 */
typedef id (^selector_block) (ReduxyState);


#pragma mark - reduxy errors

typedef NS_ENUM(NSUInteger, ReduxyError) {
    ReduxyErrorUnknown = 0,
    ReduxyErrorMultipleDispatching = 100,
};


#pragma mark - reduxy error domain

FOUNDATION_EXTERN NSErrorDomain const ReduxyErrorDomain;


#pragma mark - reduxy protocols

@protocol ReduxyActionable <NSObject>
@required
- (ReduxyActionType)type;
- (BOOL)is:(ReduxyActionType)type;

@optional
- (ReduxyActionPayload)payload;
@end

@protocol ReduxyStoreSubscriber <NSObject>
@required
- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action;
@end


@protocol ReduxyStore <NSObject>
- (ReduxyState)getState;
- (ReduxyAction)dispatch:(ReduxyAction)action;
- (ReduxyAction)dispatch:(ReduxyActionType)action payload:(ReduxyActionPayload)payload;

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber;
- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber;
@end


#pragma mark - NSString (ReduxyAction)

@interface NSString (ReduxyAction) <ReduxyActionable>
- (ReduxyActionType)type;
- (ReduxyActionPayload)payload;
@end


@interface NSDictionary (ReduxyAction) <ReduxyActionable>
- (ReduxyActionType)type;
- (ReduxyActionPayload)payload;
@end

#pragma mark - NSDictionary (ReduxyAction)

/**
 keys for NSDictionary(ReduxyAction)
 @{
   ReduxyActionTypeKey: type,
   ReduxyActionPayloadKey: payload
 }
 */
FOUNDATION_EXTERN NSString * const ReduxyActionTypeKey;
FOUNDATION_EXTERN NSString * const ReduxyActionPayloadKey;


#pragma mark - Reduxy

typedef id (^ReduxyDefaultValueBlock)(void);
typedef id (^ReduxyReduceBlock)(ReduxyState, ReduxyActionPayload);

@interface Reduxy: NSObject

#pragma mark - reducer helper
+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type defaultValue:(id)defaultValue;
+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type defaultValueBlock:(ReduxyDefaultValueBlock)defaultValueBlock;

+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type keypath:(NSString *)keypath defaultValue:(id)defaultValue;
+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type keypath:(NSString *)keypath defaultValueBlock:(ReduxyDefaultValueBlock)defaultValueBlock;

+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type reduce:(ReduxyReduceBlock)reduce defaultValueBlock:(ReduxyDefaultValueBlock)defaultValueBlock;
@end

#pragma mark - macros

/**
 macro to create a type
 */
#define ratype(type) (@(#type))


/**
 macro to create NSString action with type
 */
#define raction_no_payload(type) (@(#type))

/**
 macro to create NSDictionary action with type and payload
 */
#define raction_payload(type, ...) \
(@{ \
  ReduxyActionTypeKey: @(#type),\
  ReduxyActionPayloadKey: __VA_ARGS__ \
})

#define raction(...) raction_payload(__VA_ARGS__)

/**
 utility macro to create a middleware
 
 maybe you should be call `next(action)` at last line of block to keep chaining of middlewares
 
 ``` objc
 ReduxyMiddleware mw = rmiddleware(store, next, action, {
   NSLog(@"action: %@", action);
   return next(action);
 });
 ```
 
 @param store instance of ReduxyStore
 @param next next middleware
 @param action action dispatched
 @param block code block of middleware
 
 @return block of middleware
 */
#define rmiddleware(store, next, action, block) \
  ^ReduxyTransducer (id<ReduxyStore> store) { \
    return ^ReduxyDispatch (ReduxyDispatch next) { \
      return ^ReduxyAction (ReduxyAction action) { \
        block \
    }; \
  }; \
};


#endif /* ReduxyTypes_h */
