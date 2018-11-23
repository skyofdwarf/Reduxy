//
//  ReduxyRecoderMiddleware.m
//  Reduxy_Example
//
//  Created by yjkim on 26/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReduxyRecorder.h"


ReduxyActionType ReduxyRecorderItemAction = @"action";
ReduxyActionType ReduxyRecorderItemState = @"state";


@implementation NSDictionary (ReduxyRecorderItem)
- (ReduxyAction)action {
    return self[ReduxyRecorderItemAction];
}
- (ReduxyState)state {
    return self[ReduxyRecorderItemState];
}
@end


