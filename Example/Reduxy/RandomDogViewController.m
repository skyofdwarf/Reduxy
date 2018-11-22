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
#import "Actions.h"
#import "ReduxySimplePlayer.h"


static selector_block indicatorSelector = ^id (ReduxyState state) {
    return state[@"indicator"];
};

static selector_block imageSelector = ^id (ReduxyState state) {
    return state[@"randomdog"][@"image"];
};



@interface RandomDogViewController ()
<
ReduxyStoreSubscriber,
ReduxyRoutable
>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;

@property (copy, nonatomic) ReduxyAsyncActionCanceller canceller;

@end

@implementation RandomDogViewController

+ (NSString *)path {
    return @"randomdog";
}

- (void)dealloc {
    LOG_HERE
    
    [self.store unsubscribe:self];
}

- (void)viewDidLoad {
    LOG_HERE
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSAssert(self.store, @"No store");
    
    self.title = (self.breed?
                  self.breed:
                  @"random dog");
    
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
    
    [self.store dispatch:raction_payload(indicator, @YES)];
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithTag:@"randomdog.fetch-random"
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
                                                                       storeDispatch(raction(randomdog.reload));
                                                                       storeDispatch(raction_payload(indicator, @NO));
                                                                   }];
                                     [task resume];
                                     
                                     return ^() {
                                         LOG(@"reload is cancelled");
                                         [task cancel];
                                     };
                                 }];
    
    self.canceller = (ReduxyAsyncActionCanceller)[self.store dispatch:action];
}

- (void)loadImageWithUrlString:(NSString *)urlString {
    __weak typeof(self) wself = self;
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithTag:@"randomdog.load-image"
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
                                                                               storeDispatch(raction_payload(randomdog.reload, @{ @"image": image }));
                                                                               storeDispatch(raction_payload(indicator, @NO));
                                                                               // success
                                                                               return ;
                                                                           }
                                                                       }
                                                                       
                                                                       // fail
                                                                       storeDispatch(raction(randomdog.reload));
                                                                       storeDispatch(raction_payload(indicator, @NO));
                                                                   }];
                                     [task resume];
                                     
                                     return ^() {
                                         LOG(@"image loading is cancelled");
                                         [task cancel];
                                     };
                                 }];
    
    self.canceller = (ReduxyAsyncActionCanceller)[self.store dispatch:action];
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
    if ([action is:ratype(indicator)]) {
        NSNumber *visible = action.payload;
        if (visible.boolValue) {
            [self.indicatorView startAnimating];
        }
        else {
            [self.indicatorView stopAnimating];
        }
    }
    
    if ([action is:ratype(randomdog.reload)]) {
        self.imageView.image = action.payload[@"image];
    }
#endif
}


@end
