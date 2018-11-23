//
//  ReduxySimpleRecorder.m
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxySimpleRecorder.h"

/// replay action in middleware, recover state in reducer
ReduxyActionType ReduxyPlayerActionJump = @"reduxy.mw.player.jump";

/// replay action, do not recever state
ReduxyActionType ReduxyPlayerActionStep = @"reduxy.mw.player.step";


static NSString * const ReduxyRecorderUserDefaultKey = @"reduxy.recorder.items";

@interface ReduxySimpleRecorder ()

@property (strong, nonatomic) NSMutableArray<id<ReduxyRecorderItem>> *mutableItems;
@property (strong, nonatomic) NSSet<ReduxyActionType> *actionTypesToIgnore;

@property (strong, nonatomic) id<ReduxyStore> store;
@end


@implementation ReduxySimpleRecorder

- (void)dealloc {
    [self.store unsubscribe:self];
}

- (instancetype)initWithStore:(id<ReduxyStore>)store {
    return [self initWithStore:store actionTypesToIgnore:@[]];
}

- (instancetype)initWithStore:(id<ReduxyStore>)store actionTypesToIgnore:(NSArray<ReduxyActionType> *)typesToIgnore {
    self = [super init];
    if (self) {
        self.store = store;
        self.actionTypesToIgnore = [NSSet setWithArray:typesToIgnore];
        
        self.enabled = YES;
        
        [self clear];
        [self.store subscribe:self];
    }
    return self;
}


#pragma mark - ReduxyRecorder protocol

- (BOOL)record:(ReduxyAction)action state:(ReduxyState)state {
    if (!self.enabled) {
        return NO;
    }
    
    if ([self.actionTypesToIgnore containsObject:action.type]) {
        return NO;
    }
    
    BOOL copying = [action conformsToProtocol:@protocol(NSCopying)];
    
    [self.mutableItems addObject:@{ ReduxyRecorderItemAction: (copying?
                                                               action:
                                                               action.description),
                                    ReduxyRecorderItemState: state,
                                    }];
    
    return YES;
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
    
    LOG(@"recoder> saved %lu items", (unsigned long)self.mutableItems.count);
}

- (void)load {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    NSArray *items = [ud objectForKey:ReduxyRecorderUserDefaultKey];

    [self.mutableItems setArray:items];
    
    LOG(@"recoder> loaded %lu items: %@", (unsigned long)items.count, items);
}

#pragma mark - ReduxyStoreSubscriber

- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    if ([self record:action state:state]) {
        LOG(@"recorder subscriber> record action: %@ with state: %@", action.type, state);
    }
}

@end
