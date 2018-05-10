//
//  AppStore.m
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "AppStore.h"

@implementation AppStore

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static AppStore *instance;;
    
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}


- (ReduxyState)initalState {
    return nil;
   
}
@end
