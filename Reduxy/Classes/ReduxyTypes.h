//
//  ReduxyTypes.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#ifndef ReduxyTypes_h
#define ReduxyTypes_h

#pragma mark - reduxy protocols


@protocol ReduxyStore;
@protocol ReduxyStoreSubscriber;


typedef id ReduxyAction;
typedef id ReduxyState;


#pragma mark - reduxy function types
typedef ReduxyState (^ReduxyReducer)(ReduxyState state, ReduxyAction action);

typedef ReduxyState (^ReduxyGetState)();
typedef ReduxyAction (^ReduxyDispatch)(ReduxyAction action);

typedef ReduxyDispatch (^ReduxyTransducer)(ReduxyDispatch next);
typedef ReduxyTransducer (^ReduxyMiddleware)(id<ReduxyStore> store);


#pragma mark - reduxy error domain
FOUNDATION_EXPORT NSErrorDomain const ReduxyErrorDomain;


#pragma mark - reduxy errors

typedef NS_ENUM(NSUInteger, ReduxyError) {
    ReduxyErrorUnknown = 0,
    ReduxyErrorMultipleDispatching = 100,
};


#pragma mark - middleware helper macro

#define ReduxyMiddlewareCreateMacro(store, next, action, block) \
^ReduxyTransducer (id<ReduxyStore> store) { \
  return ^ReduxyDispatch (ReduxyDispatch next) { \
    return ^ReduxyAction (ReduxyAction action) { \
      block \
    }; \
  }; \
};




@protocol ReduxyStoreSubscriber <NSObject>
@required
- (void)reduxyStore:(id<ReduxyStore>)store stateDidChange:(ReduxyState)state;
@end


@protocol ReduxyStore <NSObject>
- (ReduxyState)getState;
- (ReduxyAction)dispatch:(ReduxyAction)action;

- (void)subscribe:(id<ReduxyStoreSubscriber>)subscriber;
- (void)unsubscribe:(id<ReduxyStoreSubscriber>)subscriber;
@end


#endif /* ReduxyTypes_h */
