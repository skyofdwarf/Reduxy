//
//  ReduxyAppDelegate.m
//  Reduxy
//
//  Created by skyofdwarf on 07/23/2017.
//  Copyright (c) 2017 skyofdwarf. All rights reserved.
//

#import "ReduxyAppDelegate.h"
#import "ReduxyRouter.h"
#import "BreedListViewController.h"
#import "ReduxyStore.h"
#import "RandomDogViewController.h"
#import "LocalStoreViewController.h"
#import "AboutViewController.h"


#pragma mark - app delegate



@interface ReduxyAppDelegate ()
@property (strong, nonatomic) ReduxyStore *store;
@property (strong, nonatomic) UIWindow *recorderWindow;

@property (strong, nonatomic) UIBarButtonItem *recoderStartButton;
@property (strong, nonatomic) UIBarButtonItem *recoderStopButton;
@property (strong, nonatomic) UIBarButtonItem *recoderSaveButton;
@property (strong, nonatomic) UIBarButtonItem *recoderLoadButton;
@property (strong, nonatomic) UIBarButtonItem *playerNextButton;

@end


@implementation ReduxyAppDelegate

+ (void)load {
    raction_add(indicator);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];
    
    [self attachRecorderUI];
    [self buildTargets];
    [self buildPaths];
    
    [ReduxyRouter.shared routePath:@"main" from:nil context:nil];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - helper

+ (instancetype)shared {
    return (ReduxyAppDelegate *)UIApplication.sharedApplication.delegate;
}


#pragma mark - recorder window

- (void)attachRecorderUI {
    UINavigationController *nv = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
    nv.toolbarHidden = NO;
    nv.topViewController.toolbarItems = [self toolbarItems];
    
    CGRect frame = UIScreen.mainScreen.bounds;
    frame.origin.y = frame.size.height - nv.toolbar.bounds.size.height;
    frame.size.height = nv.toolbar.bounds.size.height;
    
    self.recorderWindow = [[UIWindow alloc] initWithFrame:frame];
    self.recorderWindow.windowLevel = UIWindowLevelNormal + 1;
    self.recorderWindow.backgroundColor = UIColor.redColor;
    self.recorderWindow.rootViewController = nv;
    
    [self.recorderWindow makeKeyAndVisible];
    [self.recorderWindow resignKeyWindow];
}

- (NSArray *)toolbarItems {
    self.recoderStartButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                            target:self
                                                                            action:@selector(recordeStartButtonClicked:)];
    
    self.recoderStopButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                           target:self
                                                                           action:@selector(recordeStopButtonClicked:)];
    
    self.recoderSaveButton = [[UIBarButtonItem alloc] initWithTitle:@"Save"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(recordeSaveButtonClicked:)];
    self.recoderLoadButton = [[UIBarButtonItem alloc] initWithTitle:@"Load"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(recordeLoadButtonClicked:)];
    
    self.playerNextButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                                                                          target:self
                                                                          action:@selector(recordeNextButtonClicked:)];
    
    self.recoderStartButton.enabled = YES;
    self.recoderStopButton.enabled = NO;

    self.recoderSaveButton.enabled = NO;
    self.recoderLoadButton.enabled = YES;
    self.playerNextButton.enabled = NO;

    
    return @[
             self.recoderStartButton,
             
             [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                           target:nil
                                                           action:nil],
             self.recoderStopButton,
             self.recoderSaveButton,
             
             [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                           target:nil
                                                           action:nil],
             self.recoderLoadButton,
             self.playerNextButton,
             ];
}

#pragma mark - recorder window action

- (void)recordeStartButtonClicked:(id)sender {
    if (!Store.shared.recorder.recording) {
        [Store.shared.recorder start];
        ReduxyRouter.shared.routesAutoway = NO;
        
        self.recoderStartButton.enabled = NO;
        self.recoderStopButton.enabled = YES;
        
        self.recoderSaveButton.enabled = NO;
        self.recoderLoadButton.enabled = NO;
        self.playerNextButton.enabled = NO;
        
    }
}

- (void)recordeStopButtonClicked:(id)sender {
    if (Store.shared.recorder.recording) {
        [Store.shared.recorder stop];
        ReduxyRouter.shared.routesAutoway = YES;
        
        self.recoderStartButton.enabled = YES;
        self.recoderStopButton.enabled = NO;
        
        self.recoderSaveButton.enabled = YES;
        self.recoderLoadButton.enabled = YES;
        self.playerNextButton.enabled = NO;
    }
}

- (void)recordeSaveButtonClicked:(id)sender {
    [Store.shared.recorder stop];
    [Store.shared.recorder save];
    
    self.recoderStartButton.enabled = YES;
    self.recoderStopButton.enabled = NO;
    
    self.recoderSaveButton.enabled = NO;
    self.recoderLoadButton.enabled = YES;
    self.playerNextButton.enabled = NO;
}

- (void)recordeLoadButtonClicked:(id)sender {
    [Store.shared.recorder stop];
    [Store.shared.recorder load];
    
    [Store.shared.player loadItems:Store.shared.recorder.items
                          dispatch:^ReduxyAction(ReduxyAction action) {
                              return [Store.shared dispatch:action];
                          }];
    
    ReduxyRouter.shared.routesAutoway = YES;
    
    self.recoderStartButton.enabled = YES;
    self.recoderStopButton.enabled = NO;
    
    self.recoderSaveButton.enabled = NO;
    self.recoderLoadButton.enabled = YES;
    self.playerNextButton.enabled = YES;
}


- (void)recordeNextButtonClicked:(id)sender {
    self.playerNextButton.enabled = ([Store.shared.player next] != nil);
}


#pragma mark - router

- (void)buildTargets {
    [ReduxyRouter.shared addTarget:@"breedlist" creator:^id<ReduxyRoutable>(id<ReduxyRoutable> from, NSDictionary *context) {
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        BreedListViewController *dest = [sb instantiateViewControllerWithIdentifier:@"breedlist"];
        
        return dest;
    }];
    
    [ReduxyRouter.shared addTarget:@"randomdog" creator:^id<ReduxyRoutable>(id<ReduxyRoutable> from, NSDictionary *context) {
        RandomDogViewController *dest = [from.vc.storyboard instantiateViewControllerWithIdentifier:@"randomdog"];
        
        dest.store = Store.shared;
        dest.breed = context[@"breed"];
        
        return dest;
    }];
    
    [ReduxyRouter.shared addTarget:@"localstore" creator:^id<ReduxyRoutable>(id<ReduxyRoutable> from, NSDictionary *context) {
        LocalStoreViewController *dest = [from.vc.storyboard instantiateViewControllerWithIdentifier:@"localstore"];
        
        dest.breed = context[@"breed"];
        
        return dest;
    }];
    
    [ReduxyRouter.shared addTarget:@"about" creator:^id<ReduxyRoutable>(id<ReduxyRoutable> from, NSDictionary *context) {
        AboutViewController *dest = [from.vc.storyboard instantiateViewControllerWithIdentifier:@"about"];
        return dest;
    }];
}

- (void)buildPaths {
    //[ReduxyRouter.shared setInitialRoutables:@[ ReduxyAppDelegate.shared.window.rootViewController ]];
    [ReduxyRouter.shared attachStore:Store.shared];
    
    __weak typeof(self) wself = self;
    
    [ReduxyRouter.shared addPath:@"main"
                         targets:@[ @"breedlist" ]
                           route:^void(id<ReduxyRoutable> from, NSDictionary<NSString *,id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion) {
                               id<ReduxyRoutable> routable = to[@"breedlist"];
                               UINavigationController *nv = [[UINavigationController alloc] initWithRootViewController:routable.vc];
                               
                               wself.window.rootViewController = nv;
                           } unroute:^void(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion) {
                               wself.window.rootViewController = nil;
                           }];
    
    [ReduxyRouter.shared addPath:@"randomdog"
                         targets:@[ @"randomdog" ]
                           route:^void(id<ReduxyRoutable> from, NSDictionary<NSString *,id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion) {
                               id<ReduxyRoutable> routable = to[@"randomdog"];
                               
                               [from.vc showViewController:routable.vc sender:nil];
                           } unroute:^void(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion) {
                               [from.vc.navigationController popViewControllerAnimated:YES];
                           }];
    
    [ReduxyRouter.shared addPath:@"localstore"
                         targets:@[ @"localstore" ]
                           route:^void(id<ReduxyRoutable> from, NSDictionary<NSString *,id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion) {
                               id<ReduxyRoutable> routable = to[@"localstore"];
                               
                               [from.vc showViewController:routable.vc sender:nil];
                           } unroute:^void(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion) {
                               [from.vc.navigationController popViewControllerAnimated:YES];
                           }];
    
    [ReduxyRouter.shared addPath:@"about"
                         targets:@[ @"about" ]
                           route:^void(id<ReduxyRoutable> from, NSDictionary<NSString *,id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion) {
                               id<ReduxyRoutable> routable = to[@"about"];
                               
                               [from.vc showViewController:routable.vc sender:nil];
                           } unroute:^void(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion) {
                               [from.vc.navigationController popViewControllerAnimated:YES];
                           }];
    
    [ReduxyRouter.shared addPath:@"about-modal"
                         targets:@[ @"about" ]
                           route:^void(id<ReduxyRoutable> from, NSDictionary<NSString *,id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion) {
                               id<ReduxyRoutable> routable = to[@"about"];
                               
                               UINavigationController *nv = [[UINavigationController alloc] initWithRootViewController:routable.vc];
                               
                               [from.vc presentViewController:nv
                                                     animated:YES
                                                   completion:nil];
                           } unroute:^void(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion) {
                               [from.vc dismissViewControllerAnimated:YES
                                                           completion:nil];
                           }];
    
    [ReduxyRouter.shared addPath:@"split"
                         targets:@[ @"randomdog", @"about" ]
                           route:^void(id<ReduxyRoutable> from, NSDictionary<NSString *,id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion) {
                               id<ReduxyRoutable> randomdog = to[@"randomdog"];
                               id<ReduxyRoutable> about = to[@"about"];
                               
                               UISplitViewController* split = [[UISplitViewController alloc] init];
                               split.viewControllers = @[ about.vc, randomdog.vc ];
                               
                               // TODO: nv didMove 로 확인 되는지?
                               [from.vc presentViewController:split
                                                     animated:YES
                                                   completion:nil];
                           } unroute:^void(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion) {
                               [from.vc dismissViewControllerAnimated:YES
                                                           completion:nil];
                           }];
    
    [ReduxyRouter.shared addPath:@"set-vcs"
                         targets:@[ @"randomdog", @"about" ]
                           route:^void(id<ReduxyRoutable> from, NSDictionary<NSString *,id<ReduxyRoutable>> *to, NSDictionary *context, RouterRouteCompletion optionalCompletion) {
                               id<ReduxyRoutable> randomdog = to[@"randomdog"];
                               id<ReduxyRoutable> about = to[@"about"];
                               
                               [from.vc.navigationController setViewControllers:@[ from.vc, randomdog.vc, about.vc ]
                                                                       animated:YES];
                           } unroute:^void(id<ReduxyRoutable> from, RouterUnrouteCompletion optionalCompletion) {
                               [from.vc.navigationController popToRootViewControllerAnimated:YES];
                           }];
}


@end




