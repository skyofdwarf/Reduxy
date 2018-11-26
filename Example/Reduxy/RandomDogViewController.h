//
//  RandomDogViewController.h
//  Reduxy_Example
//
//  Created by yjkim on 25/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ReduxyTypes.h"
#import "ReduxyRouter.h"



@interface RandomDogViewController : UIViewController  <ReduxyRoutable>
@property (strong, nonatomic, nullable) NSString *breed;
@property (strong, nonatomic, nullable) id<ReduxyStore> store;
@end
