//
//  BreedListViewController.m
//  Reduxy_Example
//
//  Created by yjkim on 24/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "BreedListViewController.h"
#import "BreedListStore.h"


#pragma mark - selectors

static selector_block indicatorSelector = ^id (ReduxyState state) {
    return state[@"indicator"];
};

selector_block filterSelector = ^NSString *(ReduxyState state) {
    return [state valueForKeyPath:@"filter"];
};

selector_block breedsSelector = ^NSDictionary *(ReduxyState state) {
    return [state valueForKeyPath:@"breeds"];
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

@property (copy, nonatomic) selector_block filteredBreedsSelector;

@property (strong, nonatomic) ReduxyStore *store;
@end


@implementation BreedListViewController

- (void)dealloc {
    LOG_HERE
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
    
    [self attachStore];
}

- (void)viewWillAppear:(BOOL)animated {
    LOG_HERE
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    LOG_HERE
    
    [super viewDidAppear:animated];
}


- (void)viewWillDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewWillDisappear:animated];

    if (@available(iOS 11.0, *)) {
        if (self.navigationItem.searchController.active) {
            self.navigationItem.searchController.active = NO;
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    LOG_HERE
    
    [super viewDidDisappear:animated];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

- (void)attachStore {
    self.store = [BreedListStore new];
    
    [self.store subscribe:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *state = [self.store getState];
    
    NSArray *filteredBreeds = self.filteredBreedsSelector(state);
    return filteredBreeds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BreedCell" forIndexPath:indexPath];
    
    NSDictionary *state = [self.store getState];
    
    NSArray *items = self.filteredBreedsSelector(state);

    cell.textLabel.text = items[indexPath.row];
    
    return cell;
}

#pragma mark - actions

- (IBAction)reloadButtonDidClick:(id)sender {
    LOG_HERE
    
    // dispatch fetching action
    [self.store dispatch:raction(indicator, @YES)];
    
    ReduxyAsyncAction *action =
    [ReduxyAsyncAction newWithActor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch) {
        
        NSURL *url = [NSURL URLWithString:@"https://dog.ceo/api/breeds/list/all"];
        
        NSURLSessionDataTask *task =
        [NSURLSession.sharedSession dataTaskWithURL:url
                                  completionHandler:
         ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
             if (!error) {
                 NSError *jsonError = nil;
                 NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:&jsonError];
                 if (!jsonError) {
                     NSString *status = json[@"status"];
                     if ([status isEqualToString:@"success"]) {
                         NSDictionary *breeds = json[@"message"];
                         
                         storeDispatch(raction(reload, @{ @"data": @{ @"breeds": breeds,
                                                                      @"dummy": @NO,
                                                                      } }));
                         storeDispatch(raction(indicator, @NO));
                         // success
                         return ;
                     }
                 }
             }
             
             // fail
             storeDispatch(raction(reload, @{ @"data": @{ @"breeds": @[],
                                                          @"dummy": @NO,
                                                          } }));
             storeDispatch(raction(indicator, @NO));
         }];
        
        [task resume];
        
        return ^() {
            [task cancel];
            storeDispatch(raction(indicator, @NO));
        };
    }];
    
    [self.store dispatch:action];
}


#pragma mark - ReduxyStoreSubscriber

- (void)store:(ReduxyStore *)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {

    NSNumber *indicator = indicatorSelector(state);
    if (indicator.boolValue) {
        [self.indicatorView startAnimating];
    }
    else {
        [self.indicatorView stopAnimating];
    }

    [self.tableView reloadData];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    LOG(@"search bar text did change: %@", searchText);
    [self.store dispatch:raction(filter, searchText)];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text;
    
    [self.store dispatch:raction(filter, text)];
}

@end
