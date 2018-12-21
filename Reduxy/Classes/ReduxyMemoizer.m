//
//  ReduxyMemoizer.m
//  Reduxy_Example
//
//  Created by yjkim on 02/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "ReduxyMemoizer.h"


memoized_block (^memoize)(memoizable_block) = ^memoized_block (memoizable_block block) {
    __block NSArray *last_args = nil;
    __block id last_result = nil;
    
    return ^id (NSArray *args) {
        BOOL same = (last_args && args && [last_args isEqualToArray:args]);
        if (!same) {
            last_args = args;
            last_result = block(args);
        }
        
        return last_result;
    };
};

/**
 create memoized selector of `resultSelector`
 
 @param selectors selectors used as source of arguments of `resultSelector`
 @param resultSelector selector which be memoized
 @return memoized selector of `resultSelector`
 */
memoized_selector_generator memoizeSelector = ^selector_block (NSArray<selector_block> *selectors, memoized_selector_block resultSelector) {
    memoized_block memoizedResultSelector = memoize(resultSelector);
    
    return ^id (ReduxyState state) {
        NSMutableArray *args = [NSMutableArray new];
        
        for (selector_block selector in selectors) {
            id r = selector(state);
            
            [args addObject:r];
        }
        
        return memoizedResultSelector(args);
    };
};
