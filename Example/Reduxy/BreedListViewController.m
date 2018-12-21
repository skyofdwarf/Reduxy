//
//  BreedListViewController.m
//  Reduxy_Example
//
//  Created by yjkim on 24/04/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import "BreedListViewController.h"
#import "Store.h"

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
@end


@implementation BreedListViewController

+ (void)load {
    raction_add(breedlist.filtered, "note: ...");
    raction_add(breedlist.reload);
    raction_add(indicator);
}

- (NSString *)path {
    return @"breedlist";
}

- (void)dealloc {
    [Store.shared unsubscribe:self];
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
    
    [Store.shared subscribe:self];
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *state = [Store.shared getState];
    
    NSArray *filteredBreeds = self.filteredBreedsSelector(state);
    return filteredBreeds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BreedCell" forIndexPath:indexPath];
    
    NSDictionary *state = [Store.shared getState];
    
    NSArray *items = self.filteredBreedsSelector(state);

    cell.textLabel.text = items[indexPath.row];
    
    return cell;
}

#pragma mark - actions

- (IBAction)reloadButtonDidClick:(id)sender {
    LOG_HERE
    
    // dispatch fetching action
    [Store.shared dispatch:raction_payload(indicator, @YES)];
    
    ReduxyAsyncAction *action =
    [ReduxyAsyncAction newWithTag:@"breedlist.reload"
                            actor:^ReduxyAsyncActionCanceller(ReduxyDispatch storeDispatch) {
         
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
                          
                          storeDispatch(raction_payload(breedlist.reload, @{ @"breeds": breeds }));
                          storeDispatch(raction_payload(indicator, @NO));
                          // success
                          return ;
                      }
                  }
              }
              
              // fail
              storeDispatch(raction_payload(breedlist.reload, @{ @"breeds": @[] }));
              storeDispatch(raction_payload(indicator, @NO));
          }];
         
         [task resume];
         
         return ^() {
             [task cancel];
             storeDispatch(raction_payload(indicator, @NO));
         };
     }];
    
    [Store.shared dispatch:action];
}


#pragma mark - ReduxyStoreSubscriber

- (void)store:(id<ReduxyStore>)store didChangeState:(ReduxyState)state byAction:(ReduxyAction)action {

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
    
    [Store.shared dispatch:ratype(breedlist.filtered)
                 payload:@{ @"filter": searchText
                            }];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text;
    
    [Store.shared dispatch:ratype(breedlist.filtered)
                 payload:@{ @"filter": text
                            }];
}

@end
