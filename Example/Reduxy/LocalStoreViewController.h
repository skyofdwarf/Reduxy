//
//  LocalStoreViewController.h
//  Reduxy_Example
//
//  Created by yjkim on 22/11/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ReduxyTypes.h"
#import "ReduxyRouter.h"


/**
 actually you can use local store.
 */
@interface LocalStoreViewController : UIViewController <ReduxyRoutable>
@property (strong, nonatomic, nullable) NSString *breed;
@end
