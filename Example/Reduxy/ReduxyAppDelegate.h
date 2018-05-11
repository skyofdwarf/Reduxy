//
//  ReduxyAppDelegate.h
//  Reduxy
//
//  Created by skyofdwarf on 07/23/2017.
//  Copyright (c) 2017 skyofdwarf. All rights reserved.
//


#import "ReduxyStore.h"


@import UIKit;


@interface ReduxyAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (instancetype)shared;

@end
