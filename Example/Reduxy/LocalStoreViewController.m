//
//  LocalStoreViewController.m
//  Reduxy_Example
//
//  Created by yjkim on 22/11/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "LocalStoreViewController.h"
#import "ReduxyStore.h"
#import "ReduxyFunctionMiddleware.h"
#import "ReduxyAsyncAction.h"
#import "ReduxyRouter.h"
#import "Actions.h"
#import "ReduxySimplePlayer.h"


static selector_block indicatorSelector = ^id (ReduxyState state) {
    return state[@"local.indicator"];
};

static selector_block imageSelector = ^id (ReduxyState state) {
    return state[@"local.randomdog"][@"image"];
};


static ReduxyMiddleware logger = ReduxyMiddlewareCreateMacro(store, next, action, {
    LOG(@"logger> received action: %@", action);
    return next(action);
});

static ReduxyMiddleware mainQueue = ReduxyMiddlewareCreateMacro(store, next, action, {
    LOG(@"mainQueue mw> received action: %@", action.type);
    
    if ([NSThread isMainThread]) {
        LOG(@"mainQueue mw> in main-queue");
        return next(action);
    }
    else {
        LOG(@"mainQueue mw> not in main-queue, call next(acton) in async");
        dispatch_async(dispatch_get_main_queue(), ^{
            next(action);
        });
        return action;
    }
});

static ReduxyReducer rootReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    ReduxyReducer indicatorReducer = ReduxyValueReducerForAction(ratype(local.indicator), @NO);
    
    ReduxyReducer randomdogReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
        if ([action is:ratype(local.randomdog.reload)]) {
            UIImage *image = action.payload[@"image"];
            return (image? @{ @"image": image }: @{});
        }
        else {
            return (state? state: @{});
        }
    };
    
    
    return @{ @"local.breed": state[@"local.breed"],
              @"local.randomdog": randomdogReducer(state[@"local.randomdog"], action),
              @"local.indicator": indicatorReducer(state[@"local.indicator"], action),
              };
};


@interface LocalStoreViewController ()
<
ReduxyStoreSubscriber,
ReduxyRoutable
>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;

@property (strong, nonatomic) ReduxyStore *store;

@property (copy, nonatomic) ReduxyAsyncActionCanceller canceller;

@end

@implementation LocalStoreViewController

+ (NSString *)path {
    return @"localstore";
}

- (void)dealloc {
    LOG_HERE
    
    [self.store unsubscribe:self];
    
    raction_remove(local.randomdog.reload);
    raction_remove(local.indicator);
}

- (void)viewDidLoad {
    LOG_HERE
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = (self.breed?
                  self.breed:
                  @"local.randomdog");
    
    raction_add(local.randomdog.reload);
    raction_add(local.indicator);
    
    self.store = [ReduxyStore storeWithState:@{ @"local.breed": self.title,
                                                @"local.randomdog": @{},
                                                @"local.indicator": @NO
                                                }
                                     reducer:rootReducer
                                 middlewares:@[ logger, ReduxyFunctionMiddleware, mainQueue ]];
    
    [self.store subscribe:self];
    
    self.indicatorView.hidesWhenStopped = YES;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    LOG_HERE
    
    [super viewWillAppear:animated];
}


- (void)viewDidAppear:(BOOL)animated {
    LOG_HERE
    
    [super viewDidAppear:animated];
    
    [self reload];
}


- (void)viewWillDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewWillDisappear:animated];
    
    if (self.canceller) {
        self.canceller();
        self.canceller = nil;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewDidDisappear:animated];
}

#pragma mark - network

- (void)reload {
    NSString *urlString = @"https://dog.ceo/api/breeds/image/random"; ///< all random
    if (self.breed) {
        urlString = [NSString stringWithFormat:@"https://dog.ceo/api/breed/%@/images/random", self.breed];
    }
    
    __weak typeof(self) wself = self;
    
    [self.store dispatch:raction_payload(local.indicator, @YES)];
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithTag:@"local.randomdog.fetch-random"
                                                        actor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch)
                                 {
                                     NSURL *url = [NSURL URLWithString:urlString];
                                     
                                     NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url
                                                                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
                                                                   {
                                                                       wself.canceller = nil;
                                                                       
                                                                       if (!error) {
                                                                           NSError *jsonError = nil;
                                                                           NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                                                                                options:0
                                                                                                                                  error:&jsonError];
                                                                           if (!jsonError) {
                                                                               NSString *status = json[@"status"];
                                                                               if ([status isEqualToString:@"success"]) {
                                                                                   NSString *imageUrl = json[@"message"];
                                                                                   
                                                                                   [self loadImageWithUrlString:imageUrl];
                                                                                   // success
                                                                                   return ;
                                                                               }
                                                                           }
                                                                       }
                                                                       
                                                                       // fail
                                                                       storeDispatch(raction(local.randomdog.reload));
                                                                       storeDispatch(raction_payload(local.indicator, @NO));
                                                                   }];
                                     [task resume];
                                     
                                     return ^() {
                                         LOG(@"reload is cancelled");
                                         [task cancel];
                                     };
                                 }];
    
    self.canceller = [self.store dispatch:action];
}

- (void)loadImageWithUrlString:(NSString *)urlString {
    __weak typeof(self) wself = self;
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithTag:@"local.randomdog.load-image"
                                                        actor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch)
                                 {
                                     NSURL *url = [NSURL URLWithString:urlString];
                                     
                                     NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url
                                                                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
                                                                   {
                                                                       wself.canceller = nil;
                                                                       
                                                                       if (!error) {
                                                                           UIImage *image = [UIImage imageWithData:data];
                                                                           if (image) {
                                                                               storeDispatch(raction_payload(local.randomdog.reload, @{ @"image": image }));
                                                                               storeDispatch(raction_payload(local.indicator, @NO));
                                                                               // success
                                                                               return ;
                                                                           }
                                                                       }
                                                                       
                                                                       // fail
                                                                       storeDispatch(raction(local.randomdog.reload));
                                                                       storeDispatch(raction_payload(local.indicator, @NO));
                                                                   }];
                                     [task resume];
                                     
                                     return ^() {
                                         LOG(@"image loading is cancelled");
                                         [task cancel];
                                     };
                                 }];
    
    self.canceller = [self.store dispatch:action];
}

#pragma mark - actions

- (IBAction)reloadButtonDidClick:(id)sender {
    [self reload];
}

- (IBAction)nextButtonDidClick:(id)sender {
    [ReduxySimplePlayer.shared next];
}


#pragma mark - ReduxyStoreSubscriber

- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    LOG(@"state did change by action: %@\nstate: %@", action, state);
    
#if 1 // refresh by state
    NSNumber *indicator = indicatorSelector(state);
    if (indicator.boolValue) {
        [self.indicatorView startAnimating];
    }
    else {
        [self.indicatorView stopAnimating];
    }
    
    self.imageView.image = imageSelector(state);
    
#else // refresh by action
    if ([action is:ratype(local.indicator)]) {
        NSNumber *visible = action.payload;
        if (visible.boolValue) {
            [self.indicatorView startAnimating];
        }
        else {
            [self.indicatorView stopAnimating];
        }
    }
    
    if ([action is:ratype(local.randomdog.reload)]) {
        self.imageView.image = action.payload[@"image"];
    }
#endif
}


@end
