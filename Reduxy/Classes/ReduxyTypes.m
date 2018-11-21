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
NSString * const ReduxyActionPayloadKey = @"payload";


#pragma mark - reduxy error domain

NSErrorDomain const ReduxyErrorDomain = @"ReduxyErrorDomain";



#pragma mark - reducer helper

ReduxyReducer ReduxyKeyPathReducerForAction(ReduxyActionType type, NSString *keypath, id defaultValue) {
    return ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:type]) {
            id value = [action.payload valueForKeyPath:keypath];
            
            if (!value)
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"No payload value for keypath: `%@` of acton type: %@", keypath, type]
                                             userInfo:nil];
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

- (NSString *)payload {
    return nil;
}

- (BOOL)is:(ReduxyActionType)type {
    return [self.type isEqualToString:type];
}
@end


@implementation NSString (ReduxyAction)
- (NSString *)type {
    return self;
}

- (NSString *)payload {
    return self;
}

@end


@implementation NSDictionary (ReduxyAction)
- (NSString *)type {
    return [self objectForKey:ReduxyActionTypeKey];
}

- (NSDictionary *)payload {
    return [self objectForKey:ReduxyActionPayloadKey];
}

@end

