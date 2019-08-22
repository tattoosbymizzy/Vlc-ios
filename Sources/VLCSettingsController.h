/*****************************************************************************
 * VLCSettingsController.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Gleb Pinigin <gpinigin # gmail.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "IASKAppSettingsViewController.h"

@class MediaLibraryService;
@interface VLCSettingsController : IASKAppSettingsViewController

- (instancetype)initWithMediaLibraryService:(MediaLibraryService *)medialibraryService NS_DESIGNATED_INITIALIZER;

@end
