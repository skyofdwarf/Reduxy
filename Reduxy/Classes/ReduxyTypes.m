//
//  ReduxyTypes.m
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"



#pragma mark - reduxy error domain

NSErrorDomain const ReduxyErrorDomain = @"ReduxyErrorDomain";


#pragma mark - NSString (ReduxyAction)

@implementation NSString (ReduxyAction)
- (NSString *)type {
    return self;
}

- (BOOL)is:(ReduxyActionType)type {
    return [self.type isEqualToString:type];
}
- (ReduxyActionPayload)payload {
    return nil;
}

@end

#pragma mark - NSDictionary (ReduxyAction)

NSString * const ReduxyActionTypeKey = @"type";
NSString * const ReduxyActionPayloadKey = @"payload";

@implementation NSDictionary (ReduxyAction)
- (NSString *)type {
    return [self objectForKey:ReduxyActionTypeKey];
}

- (BOOL)is:(ReduxyActionType)type {
    return [self.type isEqualToString:type];
}

- (ReduxyActionPayload)payload {
    return [self objectForKey:ReduxyActionPayloadKey];
}
@end

#pragma mark - Reduxy

@implementation Reduxy

#pragma mark - reducer helper
+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type defaultValue:(id)defaultValue {
    return [self reducerForAction:type
                defaultValueBlock:^{ return defaultValue; }];
}

+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type defaultValueBlock:(ReduxyDefaultValueBlock)defaultValueBlock {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([type is:action.type]) {
            id value = action.payload;
            
            if (!value)
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"No value for action: %@", action.type]
                                             userInfo:nil];
            return value;
        }
        else {
            return (state? state: defaultValueBlock());
        }
    };
}

+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type keypath:(NSString *)keypath defaultValue:(id)defaultValue {
    return [self reducerForAction:type
                          keypath:keypath
                defaultValueBlock:^{ return defaultValue; }];
}

+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type keypath:(NSString *)keypath defaultValueBlock:(ReduxyDefaultValueBlock)defaultValueBlock {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([type is:action.type]) {
            id value = [action.payload valueForKeyPath:keypath];
            
            if (!value)
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"No value for keypath `%@` of action `%@`", keypath, action.type]
                                             userInfo:nil];
            return value;
        }
        else {
            return (state? state: defaultValueBlock());
        }
    };
}

+ (ReduxyReducer)reducerForAction:(ReduxyActionType)type reduce:(ReduxyReduceBlock)reduce defaultValueBlock:(ReduxyDefaultValueBlock)defaultValueBlock {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([type is:action.type]) {
            id value = reduce(state, action.payload);
            
            if (!value)
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"No value for action: %@", action.type]
                                             userInfo:nil];
            return value;
        }
        else {
            return (state? state: defaultValueBlock());
        }
    };
}

@end
