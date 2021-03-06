//
//  EPSReactiveTableViewController.m
//  EPSReactiveTableVIewExample
//
//  Created by Peter Stuart on 2/21/14.
//  Copyright (c) 2014 Peter Stuart. All rights reserved.
//

@import ReactiveObjC.RACEXTScope;
@import ReactiveObjC.RACEXTKeyPathCoding;

#import "EPSReactiveTableViewController.h"
#import "EPSChangeObserver.h"



@interface EPSReactiveTableViewController ()

@property (readwrite, nonatomic) RACSignal *didSelectRowSignal;
@property (readwrite, nonatomic) RACSignal *accessoryButtonTappedSignal;

@property (nonatomic) EPSChangeObserver *changeObserver;
@property (nonatomic) NSDictionary *identifiersForClasses;

@end

@implementation EPSReactiveTableViewController

@synthesize animateChanges = _animateChanges;

static NSString * const defaultCellIdentifier = @"EPSReactiveTableViewController-DefaultCellIdentifier";

#pragma mark - Public Methods

- (instancetype)init
{
    return [self initWithNibName:nil bundle:nil];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (!(self = [super initWithCoder:aDecoder])) return nil;
    return [self commonInit];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    return [self commonInit];
}

- (id)initWithStyle:(UITableViewStyle)style {
    if (!(self = [super initWithStyle:style])) return nil;
    return [self commonInit];
}

- (id)commonInit
{
    _animateChanges = YES;
    _insertAnimation = UITableViewRowAnimationAutomatic;
    _deleteAnimation = UITableViewRowAnimationAutomatic;
    _changeObserver = [EPSChangeObserver new];
    _identifiersForClasses = @{};
    
    RACSignal *didSelectMethodSignal = [self rac_signalForSelector:@selector(tableView:didSelectRowAtIndexPath:)];
    RACSignal *objectsWhenSelected = [RACObserve(self.changeObserver, objects) sample:didSelectMethodSignal];
    
    self.didSelectRowSignal = [[didSelectMethodSignal
                                zipWith:objectsWhenSelected]
                               map:^RACTuple *(RACTuple *tuple) {
                                   RACTupleUnpack(RACTuple *arguments, NSArray *objects) = tuple;
                                   RACTupleUnpack(UITableView *tableView, NSIndexPath *indexPath) = arguments;
                                   id object = [EPSReactiveTableViewController objectForIndexPath:indexPath inArray:objects];
                                   return RACTuplePack(object, indexPath, tableView);
                               }];
    
    RACSignal *accessoryTappedSignal = [self rac_signalForSelector:@selector(tableView:accessoryButtonTappedForRowWithIndexPath:)];
    RACSignal *objectsWhenAccessoryTapped = [RACObserve(self.changeObserver, objects) sample:accessoryTappedSignal];
    
    self.accessoryButtonTappedSignal = [[accessoryTappedSignal
                                         zipWith:objectsWhenAccessoryTapped]
                                        map:^RACTuple *(RACTuple *tuple) {
                                            RACTupleUnpack(RACTuple *arguments, NSArray *objects) = tuple;
                                            RACTupleUnpack(UITableView *tableView, NSIndexPath *indexPath) = arguments;
                                            id object = [EPSReactiveTableViewController objectForIndexPath:indexPath inArray:objects];
                                            return RACTuplePack(object, indexPath, tableView);
                                        }];
    return self;
}

- (void)setBindingToKeyPath:(NSString *)keyPath onObject:(id)object {
    [self.changeObserver setBindingToKeyPath:keyPath onObject:object];
}

- (void)setBindingToSignal:(RACSignal *)signal {
    [self.changeObserver setBindingToSignal:signal];
}

- (void)registerCellClass:(Class)cellClass forObjectsWithClass:(Class)objectClass {
    NSString *identifier = [EPSReactiveTableViewController identifierFromCellClass:cellClass objectClass:objectClass];
    [self.tableView registerClass:cellClass forCellReuseIdentifier:identifier];
    
    NSMutableDictionary *dictionary = [self.identifiersForClasses mutableCopy];
    dictionary[NSStringFromClass(objectClass)] = identifier;
    self.identifiersForClasses = dictionary;
}

- (NSIndexPath *)indexPathForObject:(id)object {
    return [NSIndexPath indexPathForRow:[self.changeObserver.objects indexOfObject:object] inSection:0];
}

- (id)objectForIndexPath:(NSIndexPath *)indexPath {
    return [EPSReactiveTableViewController objectForIndexPath:indexPath inArray:self.changeObserver.objects];
}

+ (id)objectForIndexPath:(NSIndexPath *)indexPath inArray:(NSArray *)array {
    return array[indexPath.row];
}

#pragma mark - Private Methods

- (void)viewDidLoad {
    [super viewDidLoad];

    @weakify(self);
    
    [self.changeObserver.changeSignal
        subscribeNext:^(RACTuple *tuple) {
            RACTupleUnpack(NSArray *rowsToRemove, NSArray *rowsToInsert) = tuple;
            
            @strongify(self);
            
            BOOL onlyOrderChanged = (rowsToRemove.count == 0) &&
            (rowsToInsert.count == 0);
            
            if (self.animateChanges == YES && onlyOrderChanged == NO) {
                [self.tableView beginUpdates];
                [self.tableView deleteRowsAtIndexPaths:rowsToRemove withRowAnimation:self.deleteAnimation];
                [self.tableView insertRowsAtIndexPaths:rowsToInsert withRowAnimation:self.insertAnimation];
                [self.tableView endUpdates];
            }
            else {
                [self.tableView reloadData];
            }
        }];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:defaultCellIdentifier];
}

+ (NSString *)identifierFromCellClass:(Class)cellClass objectClass:(Class)objectClass {
    return [NSString stringWithFormat:@"EPSReactiveTableViewController-%@-%@", NSStringFromClass(cellClass), NSStringFromClass(objectClass)];
}

- (NSString *)identifierForObject:(id)object {
    return self.identifiersForClasses[NSStringFromClass([object class])];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.changeObserver.objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id object = [self objectForIndexPath:indexPath];
    NSString *identifier = [self identifierForObject:object];
    
    if (identifier == nil) {
        return [self tableView:tableView cellForObject:object atIndexPath:indexPath];
    }
    
    UITableViewCell <EPSReactiveListCell> *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    
    if ([[cell class] conformsToProtocol:@protocol(EPSReactiveListCell)] == NO) {
        NSLog(@"EPSReactiveTableViewController Error: %@ does not conform to the <EPSReactiveListCell> protocol.", NSStringFromClass([cell class]));
    }
    
    cell.object = object;
    
    return cell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectRowForObject:[self objectForIndexPath:indexPath] atIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView accessoryButtonTappedForObject:[self objectForIndexPath:indexPath] atIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.deleteCommand execute:[self objectForIndexPath:indexPath]];
    }
}

#pragma mark - For Subclasses

- (UITableViewCell *)tableView:(UITableView *)tableView cellForObject:(id)object atIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:defaultCellIdentifier];
    cell.textLabel.text = [object description];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowForObject:(id)object atIndexPath:(NSIndexPath *)indexPath {
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForObject:(id)object atIndexPath:(NSIndexPath *)indexPath {
}

@end
