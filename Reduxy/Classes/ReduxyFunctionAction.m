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
+ (instancetype)newWithTag:(NSString *)tag actor:(ReduxyFunctionActor)actor {
    return [[ReduxyFunctionAction alloc] initWithTag:tag actor:actor];
}

- (instancetype)initWithTag:(NSString *)tag actor:(ReduxyFunctionActor)actor {
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

@end


