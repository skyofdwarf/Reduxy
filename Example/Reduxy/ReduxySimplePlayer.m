//
//  ReduxySimplePlayer.m
//  Reduxy_Example
//
//  Created by yjkim on 27/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxySimplePlayer.h"
#import "ReduxyStore.h"


@interface ReduxySimplePlayer ()
@property (strong, nonatomic) NSArray<id<ReduxyRecorderItem>> *items;
@property (assign, nonatomic) NSInteger position;

@property (copy, nonatomic) ReduxyDispatch dispatch;
@end


@implementation ReduxySimplePlayer

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static ReduxySimplePlayer *instance;
    
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadItems:@[] dispatch:nil];
    }
    return self;
}

- (void)loadItems:(NSArray<id<ReduxyRecorderItem>> *)items  dispatch:(ReduxyDispatch)dispatch {
    self.items = items;
    self.dispatch = dispatch;
    
    [self reset];
}

- (void)reset {
    self.position = -1;
}

- (BOOL)finished {
    return (self.position >= self.items.count);
}

- (ReduxyAction)prev {
    ReduxyAction action = [self jump:self.position - 1];
    
    if (action) {
        --self.position;
        return action;
    }
    
    return nil;
}

- (ReduxyAction)next {
    ReduxyAction action = [self jump:self.position + 1];
    
    if (action) {
        ++self.position;
        return action;
    }
    
    return nil;
}

- (NSInteger)length {
    return self.items.count;
}


- (ReduxyAction)step:(NSInteger)index NS_UNAVAILABLE {
    BOOL inRange = (0 <= index && index < self.items.count);
    BOOL dispatchable = (self.dispatch != nil);
    
    if (dispatchable && inRange) {
        id<ReduxyRecorderItem> item = self.items[index];

        if (item) {
            return self.dispatch(@{ ReduxyActionTypeKey: ReduxyPlayerActionStep,
                                    ReduxyActionPayloadKey: item
                                    });
        }
    }
    else {
        LOG(@"not playable: (%ld / %lu)", (long)index, (unsigned long)self.items.count);
    }
    return nil;
}

- (ReduxyAction)jump:(NSInteger)index {
    BOOL inRange = (0 <= index && index < self.items.count);
    BOOL dispatchable = (self.dispatch != nil);
    
    if (dispatchable && inRange) {
        id<ReduxyRecorderItem> item = self.items[index];
        
        if (item) {
            return self.dispatch(@{ ReduxyActionTypeKey: ReduxyPlayerActionJump,
                                    ReduxyActionPayloadKey: item
                                    });
        }
    }
    else {
        LOG(@"not playable: (%ld / %lu)", (long)index, (unsigned long)self.items.count);
    }
    return nil;
}

@end
