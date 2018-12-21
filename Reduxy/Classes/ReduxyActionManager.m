//
//  ReduxyActionManager.m
//  Reduxy_Example
//
//  Created by yjkim on 10/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ReduxyActionManager.h"

#import <objc/runtime.h>
#import <objc/message.h>


@interface ReduxyActionManager()
@property (strong, nonatomic) NSMutableArray<ReduxyActionType> *actions;
@end

@implementation ReduxyActionManager

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static ReduxyActionManager *instance;
    
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.actions = [NSMutableArray new];
    }
    return self;
}

- (void)register:(ReduxyActionType)actionType {
    if ([self.actions containsObject:actionType]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"already reigistered action type: %@", actionType]
                                     userInfo:@{ @"type": actionType }];
    }
    else {
        [self.actions addObject:actionType];
    }
}

- (void)unregister:(ReduxyActionType)actionType {
    [self.actions removeObject:actionType];
}

- (ReduxyActionType)type:(ReduxyActionType)actionType {
    // TODO: JSON schema ?
    
    if ([self.actions containsObject:actionType]) {
        return actionType;
    }
    else {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"No reigistered action type: %@", actionType]
                                     userInfo:@{ @"type": actionType }];
    }
}

- (ReduxyAction)actionWithType:(ReduxyActionType)actionType payload:(id)payload {
    if ([self.actions containsObject:actionType]) {
        return (payload?
                @{ ReduxyActionTypeKey: actionType,
                   ReduxyActionPayloadKey: payload }:
                
                @{ ReduxyActionTypeKey: actionType });
    }
    else {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"No reigistered action type: %@", actionType]
                                     userInfo:@{ @"type": actionType }];
    }
}

@end
