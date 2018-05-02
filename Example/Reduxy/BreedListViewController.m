//
//  BreedListViewController.m
//  Reduxy_Example
//
//  Created by yjkim on 24/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "BreedListViewController.h"
#import "ReduxyStore.h"
#import "ReduxyFunctionMiddleware.h"
#import "ReduxyRecorderMiddleware.h"
#import "ReduxyAsyncAction.h"
#import "RandomDogViewController.h"
#import "ReduxySimpleRecorder.h"
#import "ReduxySimplePlayer.h"
#import "ReduxyMemoizer.h"

static ReduxyActionType ReduxyActionBreedListReload = @"reduxy.action.breedlist.reload";
static ReduxyActionType ReduxyActionBreedListFetching = @"reduxy.action.breedlist.fetching";
static ReduxyActionType ReduxyActionBreedListFetched = @"reduxy.action.breedlist.fetched";
static ReduxyActionType ReduxyActionBreedListFiltered = @"reduxy.action.breedlist.filtered";
static ReduxyActionType ReduxyActionUIReload = @"reduxy.action.ui.reload";


#pragma mark - middlewares

static ReduxyMiddleware logger = ReduxyMiddlewareCreateMacro(store, next, action, {
    NSLog(@"logger> received action: %@", action);
    return next(action);
});

#pragma mark - reducers

static ReduxyReducer breedsReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    if ([action is:ReduxyActionBreedListFetched]) {
        NSDictionary *breeds = action.data[@"breeds"];
        return breeds;
    }
    else {
        return (state? state: @{});
    }
};

static ReduxyReducer filterReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    if ([action is:ReduxyActionBreedListFiltered]) {
        NSString *filter = action.data[@"filter"];
        return filter;
    }
    else {
        return (state? state: @"");
    }
};


static ReduxyReducer rootReducer = ^ReduxyState (ReduxyState state, ReduxyAction action) {
    return @{ @"fixed-menu": @[ @"Random dog" ],
              @"breeds": breedsReducer(state[@"breeds"], action),
              @"filter": filterReducer(state[@"filter"], action)
              };
};

#pragma mark - selectors

selector_block filterSelector = ^NSString *(ReduxyState state) {
    return state[@"filter"];
};

selector_block breedsSelector = ^NSDictionary *(ReduxyState state) {
    return state[@"breeds"];
};


#pragma mark - view controller

@interface BreedListViewController ()
<
UITableViewDataSource,
UITableViewDelegate,
ReduxyStoreSubscriber,
UISearchResultsUpdating,
UISearchBarDelegate
>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;

@property (strong, nonatomic) ReduxyStore *store;
@property (copy, nonatomic) selector_block filteredBreedsSelector;

@property (strong, nonatomic) ReduxySimpleRecorder *recorder;
@end

@implementation BreedListViewController

- (void)dealloc {
    [self.store unsubscribe:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self attachSearchBar];
    
    self.filteredBreedsSelector  = memoizeSelector(@[ filterSelector, breedsSelector ], ^id (NSArray *args) {
        NSString *filter = args[0];
        NSDictionary *breeds = args[1];
        
        if (filter.length) {
            NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF contains[c] %@", filter];
            return [breeds.allKeys filteredArrayUsingPredicate:p];
        }
        else {
            return breeds.allKeys;
        }
    });
    
    [self attachReduxyStore];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.store dispatch:ReduxyActionBreedListReload];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (@available(iOS 11.0, *)) {
        if (self.navigationItem.searchController.active) {
            self.navigationItem.searchController.active = NO;
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"RandomDog"]) {
        RandomDogViewController *vc = (RandomDogViewController *)segue.destinationViewController;
        vc.breed = sender;
    }
}

#pragma mark - private

- (void)attachSearchBar {
    if (@available(iOS 11.0, *)) {
        UISearchController *sc = [[UISearchController alloc] initWithSearchResultsController:nil];
        sc.searchResultsUpdater = self;
        
        if (@available(iOS 9.1, *)) {
            sc.obscuresBackgroundDuringPresentation = NO;
        }
        else {
            sc.dimsBackgroundDuringPresentation = NO;
        }
        
        self.navigationItem.searchController = sc;
    }
    else {
        UISearchBar *sb = [[UISearchBar alloc] init];
        self.navigationItem.titleView = sb;
        sb.delegate = self;
    }
}

- (ReduxyState)initialState {
    return rootReducer(nil, nil);
}

- (void)attachReduxyStore {
    self.recorder = [[ReduxySimpleRecorder alloc] initWithRootReducer:rootReducer
                                                     ignorableActions:@[ ReduxyPlayerActionJump ]];
    
    self.store = [ReduxyStore storeWithState:[self initialState]
                                     reducer:ReduxyPlayerReducerWithRootReducer(rootReducer)
                                 middlewares:@[ logger,
                                                ReduxyRecorderMiddlewareWithRecorder(self.recorder),
                                                ReduxyFunctionMiddleware,
                                                ReduxyPlayerMiddleware]];
    [self.store subscribe:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *state = [self.store getState];
    
    switch (section) {
        case 0: {
            NSArray *fixedMenu = state[@"fixed-menu"];
            return fixedMenu.count;
        }
        case 1: {
            NSArray *filteredBreeds = self.filteredBreedsSelector(state);
            return filteredBreeds.count;
        }
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BreedCell" forIndexPath:indexPath];
    
    NSDictionary *state = [self.store getState];
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSArray *items = nil;
    
    switch (section) {
        case 0: {
            items = state[@"fixed-menu"];
            break ;
        }
        case 1: {
            items = self.filteredBreedsSelector(state);
            break ;
        }
    }

    cell.textLabel.text = items[row];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *state = [self.store getState];

    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    switch (section) {
        case 0: {
            [self performSegueWithIdentifier:@"RandomDog" sender:nil];
            break ;
        }
        case 1: {
            NSArray *items = self.filteredBreedsSelector(state);
            id item = items[row];
            
            [self performSegueWithIdentifier:@"RandomDog" sender:item];
            break ;
        }
    }
}


#pragma mark - actions

- (IBAction)reloadButtonDidClick:(id)sender {
    NSLog(@" reload ");
    
    // dispatch fetching action
    [self.store dispatch:ReduxyActionBreedListFetching];
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch) {
        
        NSURL *url = [NSURL URLWithString:@"https://dog.ceo/api/breeds/list/all"];
        
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url
                                                               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                                   if (!error) {
                                                                       NSError *jsonError = nil;
                                                                       NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                                                                            options:0
                                                                                                                              error:&jsonError];
                                                                       if (!jsonError) {
                                                                           NSString *status = json[@"status"];
                                                                           if ([status isEqualToString:@"success"]) {
                                                                               NSDictionary *breeds = json[@"message"];
                                                                               
                                                                               storeDispatch(@{ @"type": ReduxyActionBreedListFetched,
                                                                                                @"breeds": breeds});
                                                                               // success
                                                                               return ;
                                                                           }
                                                                       }
                                                                   }
                                                                   
                                                                   // fail
                                                                   storeDispatch(@{ @"type": ReduxyActionBreedListFetched,
                                                                                    @"breeds": @[] });
                                                               }];
        [task resume];
        
        return ^() {
            [task cancel];
        };
    }];
    
    [self.store dispatch:action];
}

- (IBAction)recordingToggleButtonDidClick:(id)sender {
    self.recorder.enabled = !self.recorder.enabled;
    NSLog(@"recording: %d", self.recorder.enabled);
}

- (IBAction)saveButtonDidClick:(id)sender {
    [self.recorder save];
}

- (IBAction)loadButtonDidClick:(id)sender {
    [self.recorder load];
    
    ReduxyStore *store = self.store;
    
    [ReduxySimplePlayer.shared loadItems:self.recorder.items dispatch:^ReduxyAction(ReduxyAction action) {
        return [store dispatch:action];
    }];
}

- (IBAction)prevButtonDidClick:(id)sender {
    [ReduxySimplePlayer.shared prev];
}

- (IBAction)nextButtonDidClick:(id)sender {
    [ReduxySimplePlayer.shared next];
}

- (IBAction)resetButtonDidClick:(id)sender {
    [ReduxySimplePlayer.shared reset];
}


#pragma mark - ReduxyStoreSubscriber

- (void)reduxyStore:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {
    NSLog(@"state did change by action: %@\nstate: %@", action, state);

    if ([action is:ReduxyActionBreedListFetching]) {
        [self.indicatorView startAnimating];
    }

    if ([action is:ReduxyActionBreedListFetched]) {
        [self.indicatorView stopAnimating];
        [self.tableView reloadData];
    }
    
    if ([action is:ReduxyActionBreedListFiltered] ||
        [action is:ReduxyActionBreedListReload]) {
        [self.tableView reloadData];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSLog(@"search bar: %@", searchText);
    
    [self.store dispatch:@{ @"type": ReduxyActionBreedListFiltered,
                            @"filter": searchText
                            }];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text;
    
    NSLog(@"search: %@", text);
    
    [self.store dispatch:@{ @"type": ReduxyActionBreedListFiltered,
                            @"filter": text
                            }];
}
@end
