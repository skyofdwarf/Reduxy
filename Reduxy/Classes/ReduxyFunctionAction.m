//
//  ReduxyFunctionAction.m
//  Expecta
//
//  Created by yjkim on 19/02/2018.
//

#import "ReduxyFunctionAction.h"


@implementation ReduxyFunctionAction
+ (instancetype)newWithActor:(ReduxyFunctionActor)actor {
    return [[ReduxyFunctionAction alloc] initWithActor:actor];
}

- (instancetype)initWithActor:(ReduxyFunctionActor)actor {
    self = [super init];
    if (self) {
        self.call = actor;
    }
    return self;
}
@end


