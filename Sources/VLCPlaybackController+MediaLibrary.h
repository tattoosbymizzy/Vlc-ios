/*****************************************************************************
 * VLCPlaybackController+MediaLibrary.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Tobias Conradi <videolan # tobias-conradi.de>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCPlaybackController.h"

@class VLCMLMedia;
@class NSManagedObject;
@interface VLCPlaybackController (MediaLibrary)
- (void)playMediaLibraryObject:(NSManagedObject *)mediaObject;
- (void)playMedia:(VLCMLMedia *)media;
- (void)playMediaAtIndex:(NSInteger)index fromCollection:(NSArray<VLCMLMedia *> *)collection;
- (void)openMediaLibraryObject:(NSManagedObject *)mediaObject;
@end
