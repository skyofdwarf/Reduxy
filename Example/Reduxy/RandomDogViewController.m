//
//  RandomDogViewController.m
//  Reduxy_Example
//
//  Created by yjkim on 25/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "RandomDogViewController.h"
#import "ReduxyStore.h"
#import "ReduxyFunctionMiddleware.h"
#import "ReduxyAsyncAction.h"
#import "ReduxyRouter.h"


#define LOG_HERE NSLog(@"%s", __PRETTY_FUNCTION__);


static ReduxyActionType ReduxyActionRandomDogFetching = @"reduxy.action.randomdog.fetching";
static ReduxyActionType ReduxyActionRandomDogFetched = @"reduxy.action.randomdog.fetched";
static ReduxyActionType ReduxyActionUIReload = @"reduxy.action.ui.reload";



static ReduxyMiddleware logger = ReduxyMiddlewareCreateMacro(store, next, action, {
    NSLog(@"logger> received action: %@", action);
    return next(action);
});

static ReduxyReducer randomdogReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    if ([action is:ReduxyActionRandomDogFetched]) {
        UIImage *randomdog = action.data[@"randomdog"];
        return (randomdog? randomdog: NSNull.null);
    }
    else {
        return (state? state: NSNull.null);
    }
};

static ReduxyReducer rootReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    return @{ @"breed": state[@"breed"],
              @"randomdog": randomdogReducer(state[@"randomdog"], action)
              };
};





@interface RandomDogViewController () <ReduxyStoreSubscriber>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;

@property (strong, nonatomic) ReduxyStore *store;

@property (copy, nonatomic) ReduxyAsyncActionCanceller canceller;

@end

@implementation RandomDogViewController

- (void)dealloc {
    LOG_HERE
}

- (void)viewDidLoad {
    LOG_HERE
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = (self.breed?
                  self.breed:
                  @"random dog");
    
    self.store = [ReduxyStore storeWithState:@{ @"breed": self.title,
                                                }
                                     reducer:rootReducer
                                 middlewares:@[ logger, ReduxyFunctionMiddleware ]];
    
    [self.store subscribe:self];
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
    
    NSLog(@"vcs: %@", ReduxyRouter.shared.vcs);
    
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

- (void)willMoveToParentViewController:(UIViewController *)parent {
    LOG_HERE
    
    [ReduxyRouter.shared viewController:self willMoveToParentViewController:parent];
}


#pragma mark - network

- (void)reload {
    NSString *urlString = @"https://dog.ceo/api/breeds/image/random"; ///< all random
    if (self.breed)
        urlString = [NSString stringWithFormat:@"https://dog.ceo/api/breed/%@/images/random", self.breed];
    
    NSLog(@"request url: %@", urlString);
    
    __weak typeof(self) wself = self;
    
    [self.store dispatch:ReduxyActionRandomDogFetching];
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch) {
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url
                                                               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
                                                                               
                                                                               [wself loadImageWithUrlString:imageUrl];
                                                                               // success
                                                                               return ;
                                                                           }
                                                                       }
                                                                   }
                                                                   
                                                                   // fail
                                                                   storeDispatch(@{ @"type": ReduxyActionRandomDogFetched });
                                                                   
                                                               }];
        [task resume];
        
        return ^() {
            NSLog(@"reload is cancelled");
            [task cancel];
        };
    }];
    
    self.canceller = [self.store dispatch:action];
}

- (void)loadImageWithUrlString:(NSString *)urlString {
    __weak typeof(self) wself = self;
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch) {
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url
                                                               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                                   wself.canceller = nil;
                                                                   
                                                                   if (!error) {
                                                                       UIImage *image = [UIImage imageWithData:data];
                                                                       if (image) {
                                                                           storeDispatch(@{ @"type": ReduxyActionRandomDogFetched,
                                                                                            @"randomdog": image
                                                                                            });
                                                                           // success
                                                                           return ;
                                                                       }
                                                                   }
                                                                   
                                                                   // fail
                                                                   storeDispatch(@{ @"type": ReduxyActionRandomDogFetched });
                                                               }];
        [task resume];
        
        return ^() {
            NSLog(@"image loading is cancelled");
            [task cancel];
        };
    }];
    
    self.canceller = [self.store dispatch:action];
}

#pragma mark - actions

- (IBAction)reloadButtonDidClick:(id)sender {
    [self reload];
}

#pragma mark - ReduxyStoreSubscriber

- (void)reduxyStore:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    NSLog(@"state did change by action: %@\nstate: %@", action, state);
    
    if ([action is:ReduxyActionRandomDogFetching]) {
        [self.indicatorView startAnimating];
    }
    if ([action is:ReduxyActionRandomDogFetched]) {
        [self.indicatorView stopAnimating];
        self.imageView.image = action.data[@"randomdog"];
    }
}


@end
