/*****************************************************************************
 * VLCPlaybackController+MediaLibrary.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Tobias Conradi <videolan # tobias-conradi.de>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCPlaybackController+MediaLibrary.h"
#import <CoreData/CoreData.h>
#import <VLCMediaLibraryKit/VLCMLFile.h>
#import <VLCMediaLibraryKit/VLCMLMedia.h>

@implementation VLCPlaybackController (MediaLibrary)

/*
 Open a file in the libraryViewController and toggle the playstate

 @param mediaObject the object that should be openend
 
*/

- (void)playMediaLibraryObject:(NSManagedObject *)mediaObject
{
    self.fullscreenSessionRequested = YES;
    if ([mediaObject isKindOfClass:[MLFile class]]) {
        [self configureWithFile:(MLFile *)mediaObject];
    }
    else if ([mediaObject isKindOfClass:[MLAlbumTrack class]]) {
        [self configureWithAlbumTrack:(MLAlbumTrack *)mediaObject];
        self.fullscreenSessionRequested = NO;
    }
    else if ([mediaObject isKindOfClass:[MLShowEpisode class]])
        [self configureWithShowEpisode:(MLShowEpisode *)mediaObject];
}

- (void)playMediaAtIndex:(NSInteger)index fromCollection:(NSArray<VLCMLMedia *> *)collection
{
    [self configureMediaListWithMLMedia:collection indexToPlay:(int) index];
}

- (void)playMedia:(VLCMLMedia *)media
{
    [self configureMediaListWithMLMedia:@[media] indexToPlay:0];
}

/*
Open a file in the libraryViewController without changing the playstate

@param mediaObject the object that should be openend

*/

- (void)openMediaLibraryObject:(NSManagedObject *)mediaObject
{
    if (!self.isPlaying) {
        //if nothing is playing start playing
        [self playMediaLibraryObject:mediaObject];
        return;
    }
    MLFile *newFile;
    if ([mediaObject isKindOfClass:[MLAlbumTrack class]]) {
        newFile = ((MLAlbumTrack *)mediaObject).anyFileFromTrack;
    } else if ([mediaObject isKindOfClass:[MLShowEpisode class]]) {
        newFile = ((MLShowEpisode *)mediaObject).anyFileFromEpisode;
    } else if ([mediaObject isKindOfClass:[MLFile class]]) {
        newFile = (MLFile *)mediaObject;
    }

    //if the newfile is not the currently playing one, stop and start the new one else do nothing
    VLCMedia *currentlyPlayingFile = self.currentlyPlayingMedia;
    MLFile *currentMLFile = [MLFile fileForURL:currentlyPlayingFile.url].firstObject;
    if (![currentMLFile isEqual:newFile]) {
        [self stopPlayback];
        [self playMediaLibraryObject:mediaObject];
    }
}

- (void)configureWithFile:(MLFile *)file
{
    if (file.labels.count == 0) {
        [self configureMediaListWithFiles:@[file] indexToPlay:0];
    } else {
        MLLabel *folder = [file.labels anyObject];
        NSArray *files = [folder sortedFolderItems];
        int index = (int)[files indexOfObject:file];
        [self configureMediaListWithFiles:files indexToPlay:index];
    }
}

- (void)configureWithShowEpisode:(MLShowEpisode *)showEpisode
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:kVLCAutomaticallyPlayNextItem]) {
        [self playMediaLibraryObject:showEpisode.files.anyObject];
        return;
    }

    NSArray *episodes = [[showEpisode show] sortedEpisodes];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:episodes.count];
    for (MLShowEpisode *episode in episodes) {
        MLFile *file = episode.files.anyObject;
        if (file)
            [files addObject:file];
    }
    int index = (int)[episodes indexOfObject:showEpisode];
    [self configureMediaListWithFiles:files indexToPlay:index];
}

- (void)configureWithAlbumTrack:(MLAlbumTrack *)albumTrack
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:kVLCAutomaticallyPlayNextItem]) {
        [self playMediaLibraryObject:albumTrack.anyFileFromTrack];
        return;
    }

    NSArray *tracks = [[albumTrack album] sortedTracks];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:tracks.count];
    for (MLAlbumTrack *track in tracks) {
        MLFile *file = track.anyFileFromTrack;
        if (file)
            [files addObject:file];
    }
    int index = (int)[tracks indexOfObject:albumTrack];
    [self configureMediaListWithFiles:files indexToPlay:index];
}

- (void)configureMediaListWithFiles:(NSArray *)files indexToPlay:(int)index
{
    VLCMediaList *list = [[VLCMediaList alloc] init];
    VLCMedia *media;
    for (MLFile *file in files) {
        media = [VLCMedia mediaWithURL:file.url];
        [media addOptions:self.mediaOptionsDictionary];
        [list addMedia:media];
    }
    [self configureMediaList:list atIndex:index];
}

- (void)configureMediaListWithMLMedia:(NSArray<VLCMLMedia *> *)mlMedia indexToPlay:(int)index {
    NSAssert(index >= 0, @"The index should never be negative");
    VLCMediaList *list = [[VLCMediaList alloc] init];
    VLCMedia *media;
    for (VLCMLMedia *file in mlMedia) {
        media = [VLCMedia mediaWithURL: file.mainFile.mrl];
        [media addOptions:self.mediaOptionsDictionary];
        [list addMedia:media];
    }
    [self configureMediaList:list atIndex:index];
}

- (void)configureMediaList:(VLCMediaList *)list atIndex:(int)index
{
    [self playMediaList:list firstIndex:index subtitlesFilePath:nil];
}

@end
