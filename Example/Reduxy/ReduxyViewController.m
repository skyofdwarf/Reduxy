//
//  ReduxyViewController.m
//  Reduxy
//
//  Created by skyofdwarf on 07/23/2017.
//  Copyright (c) 2017 skyofdwarf. All rights reserved.
//

#import "ReduxyViewController.h"
#import "ReduxyStore.h"
#import "ReduxyAsyncAction.h"


#pragma mark - actions

ReduxyAction ReduxyActionIncrease = @"reduxy.action.increase";
ReduxyAction ReduxyActionDecrease = @"reduxy.action.decrease";

ReduxyAction ReduxyActionNotUsed = @"reduxy.action.not-used";
ReduxyAction ReduxyActionIgnore = @"reduxy.action.ignore";



#pragma mark - reducers

ReduxyReducer valueReducer = ^ReduxyState (NSNumber *state, ReduxyAction action) {
    if ([action isEqualToString:ReduxyActionIgnore])
        return @(state.integerValue + 1);
    if ([action isEqualToString:ReduxyActionDecrease])
        return @(state.integerValue - 1);
    return state;
};

ReduxyReducer notUsedReducer = ^ReduxyState (NSString *state, ReduxyAction action) {
    return state;
};

ReduxyReducer rootReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    return @{ @"value": valueReducer(state[@"value"], action),
              @"tag": notUsedReducer(state[@"tag"], action)
              };
};


#pragma mark - middlewares

ReduxyMiddleware logger = ReduxyMiddlewareCreateMacro({
    NSLog(@"sent action: %@", action);
    return nextDispatch(action);
});

ReduxyMiddleware ignorer = ReduxyMiddlewareCreateMacro({
    if ([action isKindOfClass:NSString.class]) {
        if ([(NSString *)action isEqualToString:ReduxyActionIgnore]) {
            return action;
        }
    }
    return nextDispatch(action);
});


#pragma mark - ViewController

@interface ReduxyViewController () <ReduxyStoreDelegate>
@property (weak, nonatomic) IBOutlet UITextField *customActionTextField;
@property (strong, nonatomic) ReduxyStore *store;
@end

@implementation ReduxyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self newStore];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)deallocStore {
    // clear store property to verify memory dealloction and retain cycle of ReduxyStore.    
    self.store = nil;
}

- (void)newStore {
    
    
    self.store = [ReduxyStore storeWithState:@{ @"value": @(0),
                                                @"tag": @"no tag",
                                                }
                                     reducer:rootReducer
                                 middlewares:@[ logger, ignorer, ReduxyAsyncActionMiddleware ]];
    
    [self.store subscribe:self];
}

#pragma mark - ReduxyStoreDelegate

- (void)reduxyStore:(ReduxyStore *)store stateDidChange:(id)state {
    NSLog(@"state did change: %@", state);
}

#pragma mark - actions

- (IBAction)increaseButtonDidTouch:(id)sender {
    NSLog(@"dispatched action: %@", [self.store dispatch:@"inc"]);
}

- (IBAction)decreaseButtonDidTouch:(id)sender {
    NSLog(@"dispatched action: %@", [self.store dispatch:@"dec"]);
}

- (IBAction)asyncButtonDidTouch:(id)sender {
    ReduxyAsyncAction *aa = [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller (ReduxyDispatch storeDispatch, ReduxyGetState getState) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            storeDispatch(@"async action after 3s");
        });
        
        return ^() {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                storeDispatch(@"async cancelled action after 2s");
            });
        };
    }];
    
    ReduxyAsyncActionCanceller canceller = [self.store dispatch:aa];
    
    NSLog(@"dispatched action: %@", canceller);
    
//    canceller();
}

- (IBAction)customButtonDidTouch:(id)sender {
    NSString *action = self.customActionTextField.text;
    if (action.length) {
        NSLog(@"dispatched action: %@", [self.store dispatch:action]);
    }
    else {
        self.customActionTextField.text = @"input custom action";
    }
}

- (IBAction)newStoreButtonDidTouch:(id)sender {
    [self newStore];
}

- (IBAction)deallocStoreButtonDidTouch:(id)sender {
    [self deallocStore];
}

@end
