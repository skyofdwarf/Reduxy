//
//  ReduxySimpleRecorder.m
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxySimpleRecorder.h"

static NSString * const ReduxyRecorderUserDefaultKey = @"reduxy.recorder.items";

@interface ReduxySimpleRecorder ()
@property (strong, nonatomic) NSMutableArray<id<ReduxyRecorderItem>> *mutableItems;
@property (strong, nonatomic) NSSet<ReduxyActionType> *ignorableActions;

@property (copy, nonatomic) ReduxyReducer rootReducer;
@end


@implementation ReduxySimpleRecorder

- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer {
    return [self initWithRootReducer:rootReducer ignorableActions:@[]];
}

- (instancetype)initWithRootReducer:(ReduxyReducer)rootReducer ignorableActions:(NSArray<ReduxyActionType> *)ignorableActions {
    self = [super init];
    if (self) {
        self.ignorableActions = [NSSet setWithArray:ignorableActions];
        self.rootReducer = rootReducer;
        self.enabled = YES;
        
        [self clear];
    }
    return self;
}

- (BOOL)record:(ReduxyAction)action state:(ReduxyState)state {
    if ([self.ignorableActions containsObject:action.type]) {
        return NO;
    }
    
    if (self.enabled && [action conformsToProtocol:@protocol(NSCopying)]) {
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
    
#if DEBUG
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.mutableItems
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:nil];
    if (data) {
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        LOG(@"recoder> save: %@", json);
    }
    else {
        LOG(@"recoder> save: %@", self.mutableItems);
    }
#endif
}

- (void)load {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    NSArray *items = [ud objectForKey:ReduxyRecorderUserDefaultKey];

    [self.mutableItems setArray:items];
    
#if DEBUG
    NSData *data = [NSJSONSerialization dataWithJSONObject:items
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:nil];
    if (data) {
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        LOG(@"recoder> load: %@", json);
    }
    else {
        LOG(@"recoder> load: %@", items);
    }
#endif
}

@end
