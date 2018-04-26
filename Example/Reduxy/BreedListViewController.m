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
#import "ReduxyAsyncAction.h"
#import "RandomDogViewController.h"

ReduxyActionType ReduxyActionBreedListFetching = @"reduxy.action.breedlist.fetching";
ReduxyActionType ReduxyActionBreedListFetched = @"reduxy.action.breedlist.fetched";
ReduxyActionType ReduxyActionBreeFiltered = @"reduxy.action.breedlist.filtered";
ReduxyActionType ReduxyActionUIReload = @"reduxy.action.ui.reload";



static ReduxyMiddleware logger = ReduxyMiddlewareCreateMacro(store, next, action, {
    NSLog(@"logger> received action: %@", action);
    return next(action);
});

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
    if ([action is:ReduxyActionBreeFiltered]) {
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

typedef id (^unary_argumented_block)(NSArray *args);
typedef unary_argumented_block memoizable_block;
typedef unary_argumented_block memoized_block;

memoized_block (^memoize)(memoizable_block) = ^memoized_block (memoizable_block block) {
    __block NSArray *last_args = nil;
    __block id last_result = nil;
    
    return ^id (NSArray *args) {
        BOOL same = (last_args && args && [last_args isEqualToArray:args]);
        if (!same) {
            last_args = args;
            last_result = block(args);
        }
        
        NSLog(@"return cached result: %d", same);
        
        return last_result;
    };
};


/**
 regular selector, no computations
 */
typedef id (^selector_block) (ReduxyState);

/**
 memoized resul selector, do some computations with argsuments
 */
typedef unary_argumented_block memoized_selector_block;

/**
 type of `memoizeSelector` function
 */
typedef selector_block (^memoized_selector_generator)(NSArray<selector_block> *, memoized_selector_block);


/**
 create memoized selector of `resultSelector`

 @param selectors selectors used as source of arguments of `resultSelector`
 @param resultSelector selector which be memoized
 @return memoized selector of `resultSelector`
 */
memoized_selector_generator memoizeSelector = ^selector_block (NSArray<selector_block> *selectors, memoized_selector_block resultSelector) {
    memoized_block memoizedResultSelector = memoize(resultSelector);
    
    return ^id (ReduxyState state) {
        NSMutableArray *args = [NSMutableArray new];
        
        for (selector_block selector in selectors) {
            id r = selector(state);
            
            [args addObject:r];
        }
        
        return memoizedResultSelector(args);
    };
};

selector_block filterSelector = ^NSString *(ReduxyState state) {
    return state[@"filter"];
};

selector_block breedsSelector = ^NSDictionary *(ReduxyState state) {
    return state[@"breeds"];
};

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
@end

@implementation BreedListViewController

- (void)dealloc {
    [self.store unsubscribe:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    
    self.store = [ReduxyStore storeWithState:rootReducer(nil, nil)
                                     reducer:rootReducer
                                 middlewares:@[ logger, ReduxyFunctionMiddleware ]];
    
    [self.store subscribe:self];
    
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
    
    // TODO: dispatch fetching action
    
    ReduxyAsyncAction *action = [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch) {
        storeDispatch(ReduxyActionBreedListFetching);
        
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
    
    if ([action is:ReduxyActionBreeFiltered]) {
        [self.tableView reloadData];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSLog(@"search bar: %@", searchText);
    
    [self.store dispatch:@{ @"type": ReduxyActionBreeFiltered,
                            @"filter": searchText
                            }];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text;
    
    NSLog(@"search: %@", text);
    
    [self.store dispatch:@{ @"type": ReduxyActionBreeFiltered,
                            @"filter": text
                            }];
}
@end
