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
<
ReduxyStoreSubscriber
>
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

- (BOOL)record:(ReduxyAction)action state:(ReduxyState)state {
    if (!self.enabled) {
        return NO;
    }
    
    if ([self.actionTypesToIgnore containsObject:action.type]) {
        return NO;
    }
    
    [self.mutableItems addObject:@{ ReduxyRecorderItemAction: action,
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
    LOG(@"recoder> saved %lu items", (unsigned long)self.mutableItems.count);
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
    LOG(@"recoder> loaded %lu items", (unsigned long)items.count);
}

#pragma mark - ReduxyStoreSubscriber

- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    LOG(@"recorder subscriber> record action: %@ with state: %@", action.type, state);
    
    [self record:action state:state];
}

@end
