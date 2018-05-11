//
//  ReduxyTypes.m
//  Pods
//
//  Created by skyofdwarf on 2017. 7. 23..
//
//

#import <Foundation/Foundation.h>
#import "ReduxyTypes.h"



#pragma mark - reduxy action key

NSString * const ReduxyActionTypeKey = @"type";
NSString * const ReduxyActionDataKey = @"data";


#pragma mark - reduxy error domain

NSErrorDomain const ReduxyErrorDomain = @"ReduxyErrorDomain";



#pragma mark - reducer helper

ReduxyReducer ReduxyKeyValueReducerForAction(ReduxyActionType type, NSString *key, id defaultValue) {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:type]) {
            id value = action.data[key];
            return value;
        }
        else {
            return (state? state: defaultValue);
        }
    };
};



#pragma mark - default implementations of ReduxyAction protocol

@implementation NSObject (ReduxyAction)
- (NSString *)type {
    // must be overriden
    return self.description;
}

- (BOOL)is:(ReduxyActionType)type {
    return [self.type isEqualToString:type];
}
@end


@implementation NSString (ReduxyAction)
- (NSString *)type {
    return self;
}

- (NSString *)data {
    return self;
}

- (BOOL)is:(ReduxyActionType)type {
    return [self isEqualToString:type];
}
@end


@implementation NSDictionary (ReduxyAction)
- (NSString *)type {
    return [self objectForKey:ReduxyActionTypeKey];
}

- (NSDictionary *)data {
    return self;
}

- (BOOL)is:(ReduxyActionType)type {
    return [self.type isEqualToString:type];
}
@end

