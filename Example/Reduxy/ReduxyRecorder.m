//
//  ReduxyRecorder.m
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxyRecorder.h"

static NSString * const ReduxyRecorderUserDefaultKey = @"reduxy.recorder.items";

@interface ReduxyRecorder ()
@property (strong, nonatomic) NSMutableArray<id<ReduxyRecorderItem>> *mutableItems;
@property (strong, nonatomic) NSSet<ReduxyActionType> *ignorableActions;

@property (copy, nonatomic) ReduxyReducer rootReducer;
@end


@implementation ReduxyRecorder

- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer {
    return [self initWithRootReducer:rootReducer ignorableActins:@[]];
}

- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer ignorableActins:(NSArray<ReduxyActionType> *)ignorableActions {
    self = [super init];
    if (self) {
        self.ignorableActions = [NSSet setWithArray:ignorableActions];
        self.rootReducer = rootReducer;
        self.enabled = YES;
        
        [self clear];
    }
    return self;
}

- (BOOL)recordWithAction:(ReduxyAction)action state:(ReduxyState)state {
    if ([self.ignorableActions containsObject:action.type]) {
        return NO;
    }
    
    if (self.enabled && [action conformsToProtocol:@protocol(NSCopying)]) {
        NSLog(@"recoder> recode action: %@", action);
        
        ReduxyState nextState = self.rootReducer(state, action);
        
        id item = @{ ReduxyRecorderItemAction: action,
                     ReduxyRecorderItemPrevState: state,
                     ReduxyRecorderItemNextState: nextState,
                     };
        
        [self.mutableItems addObject:item];
        
        return YES;
    }
    
    return NO;
}

- (NSArray<ReduxyRecorderItem> *)items {
    return [self.mutableItems copy];
}

- (void)clear {
    self.mutableItems = [NSMutableArray array];
}

- (void)save {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    [ud registerDefaults:@{ ReduxyRecorderUserDefaultKey: @[] }];
    [ud setObject:self.mutableItems forKey:ReduxyRecorderUserDefaultKey];
    
    [ud synchronize];
    
    NSLog(@"recoder> save: %@", self.mutableItems);
}

- (void)load {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    NSArray *items = [ud objectForKey:ReduxyRecorderUserDefaultKey];
    
    NSLog(@"recoder> load: %@", items);
    
    [self.mutableItems setArray:items];
}

@end
