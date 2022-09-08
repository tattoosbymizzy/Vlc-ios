/*****************************************************************************
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCOpenNetworkStreamTVViewController.h"
#import "VLCPlaybackService.h"
#import "VLCPlayerDisplayController.h"
#import "VLCFullscreenMovieTVViewController.h"
#import "CAAnimation+VLCWiggle.h"

@interface VLCOpenNetworkStreamTVViewController ()
{
    NSMutableArray *_recentURLs;
    NSMutableDictionary *_recentURLTitles;
    BOOL _newestFirst;
}
@property (nonatomic) NSIndexPath *currentlyFocusedIndexPath;
@end

@implementation VLCOpenNetworkStreamTVViewController

- (NSString *)title
{
    return NSLocalizedString(@"NETWORK_TITLE", nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (@available(tvOS 13.0, *)) {
        self.navigationController.navigationBarHidden = YES;
    }

    self.nothingFoundLabel.text = NSLocalizedString(@"NO_RECENT_STREAMS", nil);

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(ubiquitousKeyValueStoreDidChange:)
                               name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
                             object:[NSUbiquitousKeyValueStore defaultStore]];

    self.playURLField.placeholder = NSLocalizedString(@"ENTER_URL", nil);
    if (@available(tvOS 10.0, *)) {
        self.playURLField.textContentType = UITextContentTypeURL;
    }
    self.emptyListButton.accessibilityLabel = NSLocalizedString(@"BUTTON_RESET", nil);
    self.reverseListSortingButton.accessibilityLabel = NSLocalizedString(@"BUTTON_REVERSE", nil);

    _newestFirst = false;

    self.previouslyPlayedStreamsTableView.backgroundColor = [UIColor clearColor];
    self.previouslyPlayedStreamsTableView.rowHeight = UITableViewAutomaticDimension;

    /* After day 354 of the year, the usual VLC cone is replaced by another cone
     * wearing a Father Xmas hat.
     * Note: this icon doesn't represent an endorsement of The Coca-Cola Company
     * and should not be confused with the idea of religious statements or propagation there off
     */
    NSCalendar *gregorian =
    [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSUInteger dayOfYear = [gregorian ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitYear forDate:[NSDate date]];
    if (dayOfYear >= 354)
        self.nothingFoundConeImageView.image = [UIImage imageNamed:@"xmas-cone"];
}

- (void)viewWillAppear:(BOOL)animated
{
    /* force store update */
    NSUbiquitousKeyValueStore *ubiquitousKeyValueStore = [NSUbiquitousKeyValueStore defaultStore];
    [ubiquitousKeyValueStore synchronize];

    /* fetch data from cloud */
    _recentURLs = [NSMutableArray arrayWithArray:[ubiquitousKeyValueStore arrayForKey:kVLCRecentURLs]];
    _recentURLTitles = [NSMutableDictionary dictionaryWithDictionary:[ubiquitousKeyValueStore dictionaryForKey:kVLCRecentURLTitles]];

    [self.previouslyPlayedStreamsTableView reloadData];
    [super viewWillAppear:animated];
}

- (void)ubiquitousKeyValueStoreDidChange:(NSNotification *)notification
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(ubiquitousKeyValueStoreDidChange:) withObject:notification waitUntilDone:NO];
        return;
    }

    /* TODO: don't blindly trust that the Cloud knows best */
    _recentURLs = [NSMutableArray arrayWithArray:[[NSUbiquitousKeyValueStore defaultStore] arrayForKey:kVLCRecentURLs]];
    _recentURLTitles = [NSMutableDictionary dictionaryWithDictionary:[[NSUbiquitousKeyValueStore defaultStore] dictionaryForKey:kVLCRecentURLTitles]];
    [self.previouslyPlayedStreamsTableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    /* force update before we leave */
    [[NSUbiquitousKeyValueStore defaultStore] synchronize];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RecentlyPlayedURLsTableViewCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"RecentlyPlayedURLsTableViewCell"];
    }

    NSInteger index = _newestFirst ? _recentURLs.count - 1 - indexPath.row : indexPath.row;
    NSString *content = [_recentURLs[index] stringByRemovingPercentEncoding];
    NSString *possibleTitle = _recentURLTitles[[@(index) stringValue]];

    cell.detailTextLabel.text = content;
    cell.textLabel.text = (possibleTitle != nil) ? possibleTitle : [content lastPathComponent];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.previouslyPlayedStreamsTableView deselectRowAtIndexPath:indexPath animated:NO];
    NSInteger index = _newestFirst ? _recentURLs.count - 1 - indexPath.row : indexPath.row;
    [self _openURLStringAndDismiss:_recentURLs[index]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = _recentURLs.count;
    if (count > 0) {
        self.nothingFoundView.hidden = YES;
        self.emptyListButton.hidden = NO;
        self.reverseListSortingButton.hidden = NO;
    }
    return count;
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.currentlyFocusedIndexPath = indexPath;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (void)URLEnteredInField:(id)sender
{
    NSString *urlString = self.playURLField.text;
    NSURL *url = [NSURL URLWithString:urlString];

    if (url && url.scheme && url.host) {
        if ([_recentURLs indexOfObject:urlString] != NSNotFound)
            [_recentURLs removeObject:urlString];

        if (_recentURLs.count >= 100)
            [_recentURLs removeLastObject];
        [_recentURLs addObject:urlString];
        [[NSUbiquitousKeyValueStore defaultStore] setArray:_recentURLs forKey:kVLCRecentURLs];

        [self _openURLStringAndDismiss:urlString];
    }
}

- (void)_openURLStringAndDismiss:(NSString *)urlString
{
    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    VLCMedia *media = [VLCMedia mediaWithURL:[NSURL URLWithString:urlString]];
    VLCMediaList *medialist = [[VLCMediaList alloc] init];
    [medialist addMedia:media];

    [vpc playMediaList:medialist firstIndex:0 subtitlesFilePath:nil];
    [self presentViewController:[VLCFullscreenMovieTVViewController fullscreenMovieTVViewController]
                       animated:YES
                     completion:nil];
}

- (void)emptyListAction:(id)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"RESET_NETWORK_STREAM_LIST_TITLE", nil)
                                                                             message:NSLocalizedString(@"RESET_NETWORK_STREAM_LIST_TEXT", nil)
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"BUTTON_RESET", nil)
                                                     style:UIAlertActionStyleDestructive
                                                   handler:^(UIAlertAction *action){
        @synchronized(self->_recentURLs) {
            NSUbiquitousKeyValueStore *ubiquitousKeyValueStore = [NSUbiquitousKeyValueStore defaultStore];
            [ubiquitousKeyValueStore setArray:@[] forKey:kVLCRecentURLs];
            [ubiquitousKeyValueStore setDictionary:@{} forKey:kVLCRecentURLTitles];
            [[NSUbiquitousKeyValueStore defaultStore] synchronize];
            self->_recentURLs = [NSMutableArray array];
            self->_recentURLTitles = [NSMutableDictionary dictionary];
            [self.previouslyPlayedStreamsTableView reloadData];
        }
    }];
    [alertController addAction:deleteAction];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"BUTTON_CANCEL", nil)
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    [alertController addAction:cancelAction];
    if ([alertController respondsToSelector:@selector(setPreferredAction:)]) {
        [alertController setPreferredAction:deleteAction];
    }
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)reverseListSortingAction:(id)sender
{
    _newestFirst = !_newestFirst;
    if (_newestFirst) {
        self.reverseListSortingButton.transform = CGAffineTransformMakeRotation( M_PI );
    } else {
        self.reverseListSortingButton.transform = CGAffineTransformIdentity;
    }

    [self.previouslyPlayedStreamsTableView reloadData];
}

#pragma mark - editing

- (NSIndexPath *)indexPathToDelete
{
    NSIndexPath *indexPathToDelete = self.currentlyFocusedIndexPath;
    return indexPathToDelete;
}

- (NSString *)itemToDelete
{
    NSIndexPath *indexPathToDelete = self.indexPathToDelete;
    if (!indexPathToDelete) {
        return nil;
    }

    NSString *ret = nil;
    @synchronized(_recentURLs) {
        NSInteger index = _newestFirst ? _recentURLs.count - 1 - indexPathToDelete.item : indexPathToDelete.item;
        if (index < _recentURLs.count) {
            ret = _recentURLs[index];
        }
    }
    return ret;
}

- (void)setEditing:(BOOL)editing
{
    [super setEditing:editing];

    UITableViewCell *focusedCell = [self.previouslyPlayedStreamsTableView cellForRowAtIndexPath:self.currentlyFocusedIndexPath];
    if (editing) {
        [focusedCell.layer addAnimation:[CAAnimation vlc_wiggleAnimationwithSoftMode:YES]
                                 forKey:VLCWiggleAnimationKey];
    } else {
        [focusedCell.layer removeAnimationForKey:VLCWiggleAnimationKey];
    }
}

- (void)deleteFileAtIndex:(NSIndexPath *)indexPathToDelete
{
    [super deleteFileAtIndex:indexPathToDelete];
    if (!indexPathToDelete) {
        return;
    }
    @synchronized(_recentURLs) {
        [_recentURLs removeObjectAtIndex:indexPathToDelete.row];
    }
    [[NSUbiquitousKeyValueStore defaultStore] setArray:_recentURLs forKey:kVLCRecentURLs];

    [self.previouslyPlayedStreamsTableView reloadData];
}

@end
