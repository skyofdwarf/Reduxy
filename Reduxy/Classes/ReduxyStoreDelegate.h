//
//  ReduxyStoreDelegate.h
//  Reduxy
//
//  Created by skyofdwarf on 2017. 7. 23..
//  Copyright © 2017년 dwarfini. All rights reserved.
//

#import <Foundation/Foundation.h>

/// forward declaration
@class ReduxyStore;

/// reduxy store store delegate
@protocol ReduxyStoreDelegate <NSObject>
@required
- (void)reduxyStore:(ReduxyStore *)store stateDidChange:(id)state;
@end
