//
//  ReduxyFunctionAction.m
//  Expecta
//
//  Created by yjkim on 19/02/2018.
//

#import "ReduxyFunctionAction.h"

@interface ReduxyFunctionAction ()
@property (copy, nonatomic) ReduxyFunctionActor call;
@property (copy, nonatomic) NSString *tag;
@end

@implementation ReduxyFunctionAction

+ (instancetype)newWithActor:(ReduxyFunctionActor)actor {
    return [[ReduxyFunctionAction alloc] initWithActor:actor];
}

+ (instancetype)newWithActor:(ReduxyFunctionActor)actor tag:(NSString *)tag {
    return [[ReduxyFunctionAction alloc] initWithActor:actor tag:tag];
}


- (instancetype)initWithActor:(ReduxyFunctionActor)actor {
    return [self initWithActor:actor tag:@"untagged"];
}

- (instancetype)initWithActor:(ReduxyFunctionActor)actor tag:(NSString *)tag {
    self = [super init];
    if (self) {
        self.tag = tag;
        self.call = actor;
    }
    return self;
}

- (NSString *)type {
    return @"ReduxyFunctionAction";
}

- (BOOL)is:(ReduxyActionType)type {
    return [self.type isEqualToString:type];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: %@", self.type, self.tag];
}

@end


