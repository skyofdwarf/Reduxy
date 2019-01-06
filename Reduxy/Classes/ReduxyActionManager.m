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
@property (strong, nonatomic) NSMutableSet<ReduxyActionType> *actions;
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
    return [self initWithActions:@[]];
}

- (instancetype)initWithActions:(NSArray<ReduxyActionType> *)actions {
    self = [super init];
    if (self) {
        self.actions = [[NSMutableSet alloc] initWithArray:actions];
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

- (BOOL)valid:(ReduxyAction)action {
    return [self.actions containsObject:action.type];
}

- (void)validate:(ReduxyAction)action {
    if (![self valid:action]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"No reigistered action with type: %@", action.type]
                                     userInfo:@{ @"type": action.type }];
    }
}

@end
