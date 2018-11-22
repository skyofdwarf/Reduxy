//
//  Store.h
//  Reduxy_Example
//
//  Created by yjkim on 03/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxyStore.h"
#import "ReduxySimpleRecorder.h"


@interface Store : ReduxyStore
@property (strong, nonatomic, readonly) ReduxySimpleRecorder *recorder;

+ (Store *)shared;

@end
