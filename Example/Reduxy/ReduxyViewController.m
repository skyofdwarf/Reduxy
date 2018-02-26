//
//  ReduxyViewController.m
//  Reduxy
//
//  Created by skyofdwarf on 07/23/2017.
//  Copyright (c) 2017 skyofdwarf. All rights reserved.
//

#import "ReduxyViewController.h"
#import "ReduxyStore.h"
#import "ReduxyFunctionMiddleware.h"
#import "ReduxyAsyncAction.h"
#import "ReduxyFunctionAction.h"


#pragma mark - actions

ReduxyAction ReduxyActionTag = @"reduxy.action.tag";

ReduxyAction ReduxyActionIncrease = @"reduxy.action.increase";
ReduxyAction ReduxyActionDecrease = @"reduxy.action.decrease";

ReduxyAction ReduxyActionNotUsed = @"reduxy.action.not-used";
ReduxyAction ReduxyActionIgnore = @"reduxy.action.ignore";



#pragma mark - reducers

ReduxyReducer valueReducer = ^ReduxyState (NSNumber *state, ReduxyAction action) {
    if ([ReduxyActionIncrease isEqual:action])
        return @(state.integerValue + 1);
    if ([ReduxyActionDecrease isEqual:action])
        return @(state.integerValue - 1);
    return state;
};

ReduxyReducer innerReducer = ^ReduxyState (NSString *state, ReduxyAction action) {
    if ([ReduxyActionTag isEqualToString:action]) {
        return @"modified inner value";
    }
    return state;
};

ReduxyReducer tagReducer = ^ReduxyState (NSDictionary *state, ReduxyAction action) {
    return @{ @"inner key": innerReducer(state[@"inner key"], action),
              @"const key": @"const value"
              };
};

ReduxyReducer rootReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    return @{ @"value": valueReducer(state[@"value"], action),
              @"tag": tagReducer(state[@"tag"], action)
              };
};


#pragma mark - middlewares

ReduxyMiddleware logger = ReduxyMiddlewareCreateMacro(store, next, action, {
    NSLog(@"logger> received action: %@", action);
    return next(action);
});

ReduxyMiddleware ignorer = ReduxyMiddlewareCreateMacro(store, next, action, {
    NSLog(@"ignorer> received action: %@", action);
    if ([action isKindOfClass:NSString.class]) {
        if ([(NSString *)action isEqualToString:ReduxyActionIgnore]) {
            NSLog(@"ignorer> ignored: %@", action);
            return action;
        }
    }
    return next(action);
});

#pragma mark - ViewController

@interface ReduxyViewController () <ReduxyStoreSubscriber>
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
                                                @"tag": @{ @"inner key": @"inner value",
                                                           @"const key": @"const value"
                                                           }
                                                }
                                     reducer:rootReducer
                                 middlewares:@[ logger, ignorer, /*ReduxyAsyncActionMiddleware,*/ ReduxyFunctionMiddleware ]];
    
    [self.store subscribe:self];
}

#pragma mark - ReduxyStoreSubscriber

- (void)reduxyStore:(ReduxyStore *)store stateDidChange:(id)state {
    NSLog(@"state did change: %@", state);
}

#pragma mark - actions

- (IBAction)tagButtonDidTouch:(id)sender {
    NSLog(@"dispatched action: %@", [self.store dispatch:ReduxyActionTag]);
}

- (IBAction)increaseButtonDidTouch:(id)sender {
    NSLog(@"dispatched action: %@", [self.store dispatch:ReduxyActionIncrease]);
}

- (IBAction)decreaseButtonDidTouch:(id)sender {
    NSLog(@"dispatched action: %@", [self.store dispatch:ReduxyActionDecrease]);
}

- (IBAction)asyncButtonDidTouch:(id)sender {
    ReduxyAsyncAction *aa = [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller (ReduxyDispatch storeDispatch) {
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


- (IBAction)cancellingAsyncButtonDidTouch:(id)sender {
    static BOOL s_cancelled = NO;
    
    s_cancelled = NO;
    
    ReduxyAsyncAction *aa = [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller (ReduxyDispatch storeDispatch) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!s_cancelled) {
                storeDispatch(@"async action after 3s");
            }
        });
        
        return ^() {
            //dispatch(@"async cancelled action after 2s");
            NSLog(@"cancelled");
            s_cancelled = YES;
        };
    }];
    
    ReduxyAsyncActionCanceller canceller = [self.store dispatch:aa];
    
    NSLog(@"dispatched action: %@", canceller);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        canceller();
        NSLog(@"called canceller");
    });
}

- (IBAction)bypassFunctionButtonDidTouch:(id)sender {
    // bypass middleware
    ReduxyFunctionAction *action = [ReduxyFunctionAction newWithActor:^ReduxyAction(id<ReduxyStore> store, ReduxyDispatch next, ReduxyAction action) {
        return next(action);
    }];
    
    ReduxyAction dispatchedAction = [self.store dispatch:action];
    
    NSLog(@"dispatched actin: %@", dispatchedAction);
}

- (IBAction)asyncFunctionButtonDidTouch:(id)sender {
    ReduxyFunctionAction *action = [ReduxyFunctionAction newWithActor:^ReduxyAction(id<ReduxyStore> store, ReduxyDispatch next, ReduxyAction action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [store dispatch:@"async action after 3s"];
        });
        
        return ^{
            //[store dispatch:@"async cancelled action after 2s");
            NSLog(@"cancelled");
        };
    }];
    
    
    ReduxyAction dispatchedAction = [self.store dispatch:action];
    
    NSLog(@"dispatched actin: %@", dispatchedAction);
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
