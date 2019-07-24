/*****************************************************************************
 * VLCHTTPConnection.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013-2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *          Pierre Sagaspe <pierre.sagaspe # me.com>
 *          Carola Nitz <caro # videolan.org>
 *          Jean-Baptiste Kempf <jb # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCActivityManager.h"
#import "VLCHTTPConnection.h"
#import "MultipartFormDataParser.h"
#import "HTTPMessage.h"
#import "HTTPDataResponse.h"
#import "HTTPFileResponse.h"
#import "MultipartMessageHeaderField.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPErrorResponse.h"
#import "NSString+SupportedMedia.h"
#import "UIDevice+VLC.h"
#import "VLCHTTPUploaderController.h"
#import "VLCMetaData.h"

#if TARGET_OS_IOS
#import "VLC-Swift.h"
#import "VLCThumbnailsCache.h"
#endif
#if TARGET_OS_TV
#import "VLCPlayerControlWebSocket.h"
#endif

@interface VLCHTTPConnection()
{
    MultipartFormDataParser *_parser;
    NSFileHandle *_storeFile;
    NSString *_filepath;
    UInt64 _contentLength;
    UInt64 _receivedContent;
#if TARGET_OS_TV
    NSMutableArray *_receivedFiles;
#endif
}
@end

@implementation VLCHTTPConnection

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    // Add support for POST
    if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/upload.json"])
        return YES;

    return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    // Inform HTTP server that we expect a body to accompany a POST request
    if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/upload.json"]) {
        // here we need to make sure, boundary is set in header
        NSString* contentType = [request headerField:@"Content-Type"];
        NSUInteger paramsSeparator = [contentType rangeOfString:@";"].location;
        if (NSNotFound == paramsSeparator)
            return NO;

        if (paramsSeparator >= contentType.length - 1)
            return NO;

        NSString* type = [contentType substringToIndex:paramsSeparator];
        if (![type isEqualToString:@"multipart/form-data"]) {
            // we expect multipart/form-data content type
            return NO;
        }

        // enumerate all params in content-type, and find boundary there
        NSArray* params = [[contentType substringFromIndex:paramsSeparator + 1] componentsSeparatedByString:@";"];
        NSUInteger count = params.count;
        for (NSUInteger i = 0; i < count; i++) {
            NSString *param = params[i];
            paramsSeparator = [param rangeOfString:@"="].location;
            if ((NSNotFound == paramsSeparator) || paramsSeparator >= param.length - 1)
                continue;

            NSString* paramName = [param substringWithRange:NSMakeRange(1, paramsSeparator-1)];
            NSString* paramValue = [param substringFromIndex:paramsSeparator+1];

            if ([paramName isEqualToString: @"boundary"])
                // let's separate the boundary from content-type, to make it more handy to handle
                [request setHeaderField:@"boundary" value:paramValue];
        }
        // check if boundary specified
        if (nil == [request headerField:@"boundary"])
            return NO;

        return YES;
    }
    return [super expectsRequestBodyFromMethod:method atPath:path];
}

- (NSObject<HTTPResponse> *)_httpPOSTresponseUploadJSON
{
    return [[HTTPDataResponse alloc] initWithData:[@"\"OK\"" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL)fileIsInDocumentFolder:(NSString*)filepath
{
    if (!filepath) return NO;

    NSError *error;

    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directoryPath = [searchPaths firstObject];

    NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:&error];

    if (error != nil) {
        APLog(@"checking filerelationship failed %@", error);
        return NO;
    }

    return [array containsObject:filepath.lastPathComponent];
}

#if TARGET_OS_IOS
- (NSObject<HTTPResponse> *)_httpGETDownloadForPath:(NSString *)path
{
    NSString *filePath = [[path stringByReplacingOccurrencesOfString:@"/download/" withString:@""] stringByRemovingPercentEncoding];
    if (![self fileIsInDocumentFolder:filePath]) {
       //return nil which gets handled as resource not found
        return nil;
    }
    HTTPFileResponse *fileResponse = [[HTTPFileResponse alloc] initWithFilePath:filePath forConnection:self];
    fileResponse.contentType = @"application/octet-stream";
    return fileResponse;
}

- (NSObject<HTTPResponse> *)_httpGETThumbnailForPath:(NSString *)path
{
    NSString *filePath = [[path stringByReplacingOccurrencesOfString:@"/Thumbnail/" withString:@""] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet];

    if ([filePath isEqualToString:@"/"]) return [[HTTPErrorResponse alloc] initWithErrorCode:404];

    UIImage *thumbnail = [UIImage imageWithContentsOfFile:filePath];
    if (!thumbnail) return [[HTTPErrorResponse alloc] initWithErrorCode:404];

    NSData *theData = UIImageJPEGRepresentation(thumbnail, .9);

    if (!theData) return [[HTTPErrorResponse alloc] initWithErrorCode:404];

    HTTPDataResponse *dataResponse = [[HTTPDataResponse alloc] initWithData:theData];
    dataResponse.contentType = @"image/jpg";
    return dataResponse;
}

- (NSObject<HTTPResponse> *)_httpGETLibraryForPath:(NSString *)path
{
    NSString *filePath = [self filePathForURI:path];
    NSString *documentRoot = [config documentRoot];
    NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];
    BOOL shouldReturnLibVLCXML = [relativePath isEqualToString:@"/libMediaVLC.xml"];

    NSArray *allMedia = [self allMedia];
    return shouldReturnLibVLCXML ? [self generateXMLResponseFrom:allMedia path:path] : [self generateHttpResponseFrom:allMedia path:path];
}

- (NSArray *)allMedia
{
    MediaLibraryService* medialibrary = [[VLCHTTPUploaderController sharedInstance] medialibrary];

    // Adding all Albums
    NSMutableArray *allMedia = [[medialibrary albumsWithSortingCriteria:VLCMLSortingCriteriaDefault desc:false] mutableCopy] ?: [NSMutableArray new];
    // Adding all Playlists
    [allMedia addObjectsFromArray:[medialibrary playlistsWithSortingCriteria:VLCMLSortingCriteriaDefault desc:false]];
    // Adding all Videos files
    [allMedia addObjectsFromArray:[medialibrary mediaOfType:VLCMLMediaTypeVideo sortingCriteria:VLCMLSortingCriteriaDefault desc:false]];

    //TODO: add all shows
    // Adding all audio files which are not in an Album
    NSArray* audioFiles = [medialibrary mediaOfType:VLCMLMediaTypeAudio sortingCriteria:VLCMLSortingCriteriaDefault desc:false];
    for (VLCMLMedia *track in audioFiles) {
        if (track.subtype != VLCMLMediaSubtypeAlbumTrack) {
            [allMedia addObject:track];
        }
    }
    return [allMedia copy];
}

- (NSString *)createHTMLMediaObjectFromMedia:(VLCMLMedia *)media
{
    return [NSString stringWithFormat:
            @"<div style=\"background-image:url('Thumbnail/%@')\"> \
            <a href=\"download/%@\" class=\"inner\"> \
            <div class=\"down icon\"></div> \
            <div class=\"infos\"> \
            <span class=\"first-line\">%@</span> \
            <span class=\"second-line\">%@ - %@</span> \
            </div> \
            </a> \
            </div>",
            media.thumbnail.path,
            [[media mainFile].mrl.path
             stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet],
            media.title,
            [media mediaDuration], [media formatSize]];
}

- (NSString *)createHTMLFolderObjectWithImagePath:(NSString *)imagePath
                                             name:(NSString *)name
                                            count:(NSUInteger)count
{
    return [NSString stringWithFormat:
            @"<div style=\"background-image:url('Thumbnail/%@')\"> \
            <a href=\"#\" class=\"inner folder\"> \
            <div class=\"open icon\"></div> \
            <div class=\"infos\"> \
            <span class=\"first-line\">%@</span> \
            <span class=\"second-line\">%lu items</span> \
            </div> \
            </a> \
            <div class=\"content\">",
            imagePath,
            name,
            count];
}

- (HTTPDynamicFileResponse *)generateHttpResponseFrom:(NSArray *)media path:(NSString *)path
{
    NSMutableArray *mediaInHtml = [[NSMutableArray alloc] initWithCapacity:media.count];
    for (NSObject <VLCMLObject> *mediaObject in media) {
        if ([mediaObject isKindOfClass:[VLCMLMedia class]]) {
            [mediaInHtml addObject:[self createHTMLMediaObjectFromMedia:(VLCMLMedia *)mediaObject]];
        } else if ([mediaObject isKindOfClass:[VLCMLPlaylist class]]) {
            VLCMLPlaylist *playlist = (VLCMLPlaylist *)mediaObject;
            NSArray *playlistItems = [playlist media];
            [mediaInHtml addObject: [self createHTMLFolderObjectWithImagePath:playlist.artworkMrl
                                                                name:playlist.name
                                                               count:playlistItems.count]];
            for (VLCMLMedia *media in playlistItems) {
                [mediaInHtml addObject:[self createHTMLMediaObjectFromMedia:media]];
            }
            [mediaInHtml addObject:@"</div></div>"];
        } else if ([mediaObject isKindOfClass:[VLCMLAlbum class]]) {
            VLCMLAlbum *album = (VLCMLAlbum *)mediaObject;
            NSArray *albumTracks = [album tracks];
            [mediaInHtml addObject:[self createHTMLFolderObjectWithImagePath:[album artworkMRL].path
                                                                        name:album.title
                                                                       count:albumTracks.count]];
            for (VLCMLMedia *track in albumTracks) {
                [mediaInHtml addObject:[self createHTMLMediaObjectFromMedia:track]];
            }
            [mediaInHtml addObject:@"</div></div>"];
        }
    } // end of forloop
    NSString *deviceModel = [[UIDevice currentDevice] model];

    NSDictionary *replacementDict = @{@"FILES" : [mediaInHtml componentsJoinedByString:@" "],
                        @"WEBINTF_TITLE" : NSLocalizedString(@"WEBINTF_TITLE", nil),
                        @"WEBINTF_DROPFILES" : NSLocalizedString(@"WEBINTF_DROPFILES", nil),
                        @"WEBINTF_DROPFILES_LONG" : [NSString stringWithFormat:NSLocalizedString(@"WEBINTF_DROPFILES_LONG", nil), deviceModel],
                        @"WEBINTF_DOWNLOADFILES" : NSLocalizedString(@"WEBINTF_DOWNLOADFILES", nil),
                        @"WEBINTF_DOWNLOADFILES_LONG" : [NSString stringWithFormat: NSLocalizedString(@"WEBINTF_DOWNLOADFILES_LONG", nil), deviceModel]};
    HTTPDynamicFileResponse *fileResponse = [[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
                                                       forConnection:self
                                                           separator:@"%%"
                                               replacementDictionary:replacementDict];
    fileResponse.contentType = @"text/html";

    return fileResponse;
}

- (HTTPDynamicFileResponse *)generateXMLResponseFrom:(NSArray *)media path:(NSString *)path
{
    NSMutableArray *mediaInXml = [[NSMutableArray alloc] initWithCapacity:media.count];
    NSString *hostName = [NSString stringWithFormat:@"%@:%@", [[VLCHTTPUploaderController sharedInstance] hostname], [[VLCHTTPUploaderController sharedInstance] hostnamePort]];
    for (NSObject <VLCMLObject> *mediaObject in media) {
        if ([mediaObject isKindOfClass:[VLCMLMedia class]]) {
            VLCMLMedia *file = (VLCMLMedia *)mediaObject;
            NSString *pathSub = [self _checkIfSubtitleWasFound:[file mainFile].mrl.path];
            if (pathSub)
                pathSub = [NSString stringWithFormat:@"http://%@/download/%@", hostName, pathSub];
            [mediaInXml addObject:[NSString stringWithFormat:@"<Media title=\"%@\" thumb=\"http://%@/Thumbnail/%@\" duration=\"%@\" size=\"%@\" pathfile=\"http://%@/download/%@\" pathSubtitle=\"%@\"/>",
                                   file.title,
                                   hostName,
                                   file.thumbnail.path,
                                   [file mediaDuration], [file formatSize],
                                   hostName,
                                   [[file mainFile].mrl.path stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet], pathSub]];
        } else if ([mediaObject isKindOfClass:[VLCMLPlaylist class]]) {
            VLCMLPlaylist *playlist = (VLCMLPlaylist *)mediaObject;
            NSArray *playlistItems = [playlist media];
            for (VLCMLMedia *file in playlistItems) {
                NSString *pathSub = [self _checkIfSubtitleWasFound:[file mainFile].mrl.path];
                if (pathSub)
                    pathSub = [NSString stringWithFormat:@"http://%@/download/%@", hostName, pathSub];
                [mediaInXml addObject:[NSString stringWithFormat:@"<Media title=\"%@\" thumb=\"http://%@/Thumbnail/%@\" duration=\"%@\" size=\"%@\" pathfile=\"http://%@/download/%@\" pathSubtitle=\"%@\"/>", file.title,
                                       hostName,
                                       file.thumbnail.path,
                                       [file mediaDuration],
                                       [file formatSize],
                                       hostName,
                                       [[file mainFile].mrl.path stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet], pathSub]];
            }
        } else if ([mediaObject isKindOfClass:[VLCMLAlbum class]]) {
            VLCMLAlbum *album = (VLCMLAlbum *)mediaObject;
            NSArray *albumTracks = [album tracks];
            for (VLCMLMedia *track in albumTracks) {

                [mediaInXml addObject:[NSString stringWithFormat:@"<Media title=\"%@\" thumb=\"http://%@/Thumbnail/%@\" duration=\"%@\" size=\"%@\" pathfile=\"http://%@/download/%@\" pathSubtitle=\"\"/>", track.title,
                                       hostName,
                                       track.thumbnail.path,
                                       [track mediaDuration],
                                       [track formatSize],
                                       hostName,
                                       [[track mainFile].mrl.path stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet]]];
            }
        }
    } // end of forloop

    NSDictionary *replacementDict = @{@"FILES" : [mediaInXml componentsJoinedByString:@" "],
                        @"NB_FILE" : [NSString stringWithFormat:@"%li", (unsigned long)mediaInXml.count],
                        @"LIB_TITLE" : [[UIDevice currentDevice] name]};

    HTTPDynamicFileResponse *fileResponse = [[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
                                                       forConnection:self
                                                           separator:@"%%"
                                               replacementDictionary:replacementDict];
    fileResponse.contentType = @"application/xml";
    return fileResponse;
}
#else
- (NSObject<HTTPResponse> *)_httpGETLibraryForPath:(NSString *)path
{
    UIDevice *currentDevice = [UIDevice currentDevice];
    NSString *deviceModel = [currentDevice model];
    NSString *filePath = [self filePathForURI:path];
    NSString *documentRoot = [config documentRoot];
    NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];
    NSDictionary *replacementDict = @{@"WEBINTF_TITLE" : NSLocalizedString(@"WEBINTF_TITLE_ATV", nil),
                                      @"WEBINTF_DROPFILES" : NSLocalizedString(@"WEBINTF_DROPFILES", nil),
                                      @"WEBINTF_DROPFILES_LONG" : [NSString stringWithFormat:NSLocalizedString(@"WEBINTF_DROPFILES_LONG_ATV", nil), deviceModel],
                                      @"WEBINTF_OPEN_URL" : NSLocalizedString(@"ENTER_URL", nil)};

    HTTPDynamicFileResponse *fileResponse;
    if ([relativePath isEqualToString:@"/index.html"]) {
        fileResponse = [[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
                                                           forConnection:self
                                                               separator:@"%%"
                                                   replacementDictionary:replacementDict];
        fileResponse.contentType = @"text/html";
    }

    return fileResponse;
}
#endif


- (NSObject<HTTPResponse> *)_httpGETCSSForPath:(NSString *)path
{
#if TARGET_OS_IOS
    NSDictionary *replacementDict = @{@"WEBINTF_TITLE" : NSLocalizedString(@"WEBINTF_TITLE", nil)};
#else
    NSDictionary *replacementDict = @{@"WEBINTF_TITLE" : NSLocalizedString(@"WEBINTF_TITLE_ATV", nil)};
#endif
    HTTPDynamicFileResponse *fileResponse = [[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
                                                                                forConnection:self
                                                                                    separator:@"%%"
                                                                        replacementDictionary:replacementDict];
    fileResponse.contentType = @"text/css";
    return fileResponse;
}

#if TARGET_OS_TV
- (NSObject <HTTPResponse> *)_HTTPGETPlaying
{
    /* JSON response:
     {
        "currentTime": 42,
        "media": {
            "id": "some id",
            "title": "some title",
            "duration": 120000
        }
     }
     */

    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
    if (!vpc.isPlaying) {
        return [[HTTPErrorResponse alloc] initWithErrorCode:404];
    }
    VLCMedia *media = [vpc currentlyPlayingMedia];
    if (!media) {
        return [[HTTPErrorResponse alloc] initWithErrorCode:404];
    }

    NSString *mediaTitle = vpc.metadata.title;
    if (!mediaTitle)
        mediaTitle = @"";
    NSDictionary *mediaDict = @{ @"id" : media.url.absoluteString,
                                 @"title" : mediaTitle,
                                 @"duration" : @([vpc mediaDuration])};
    NSDictionary *returnDict = @{ @"currentTime" : @([vpc playedTime].intValue),
                                  @"media" : mediaDict };

    NSError *error;
    NSData *returnData = [NSJSONSerialization dataWithJSONObject:returnDict options:0 error:&error];
    if (error != nil) {
        APLog(@"JSON serialization failed %@", error);
        return [[HTTPErrorResponse alloc] initWithErrorCode:500];
    }

    return [[HTTPDataResponse alloc] initWithData:returnData];
}

- (NSObject <HTTPResponse> *)_HTTPGETwebResources
{
    /* JS response
     {
        "WEBINTF_URL_SENT" : "URL sent successfully.",
        "WEBINTF_URL_EMPTY" :"'URL cannot be empty.",
        "WEBINTF_URL_INVALID" : "Not a valid URL."
     }
     */

    NSString *returnString = [NSString stringWithFormat:
                              @"var LOCALES = {\n" \
                                         "PLAYER_CONTROL: {\n" \
                                         "URL: {\n" \
                                         "EMPTY: \"%@\",\n" \
                                         "NOT_VALID: \"%@\",\n" \
                                         "SENT_SUCCESSFULLY: \"%@\"\n" \
                                         "}\n" \
                                         "}\n" \
                              "}",
                              NSLocalizedString(@"WEBINTF_URL_EMPTY", nil),
                              NSLocalizedString(@"WEBINTF_URL_INVALID", nil),
                              NSLocalizedString(@"WEBINTF_URL_SENT", nil)];

    NSData *returnData = [returnString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    return [[HTTPDataResponse alloc] initWithData:returnData];
}

- (NSObject <HTTPResponse> *)_HTTPGETPlaylist
{
    /* JSON response:
     [
        {
            "media": {
                "id": "some id 1",
                "title": "some title 1",
                "duration": 120000
            }
        },
     ...]
     */

    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
    if (!vpc.isPlaying || !vpc.mediaList) {
        return [[HTTPErrorResponse alloc] initWithErrorCode:404];
    }

    VLCMediaList *mediaList = vpc.mediaList;
    [mediaList lock];
    NSUInteger mediaCount = mediaList.count;
    NSMutableArray *retArray = [NSMutableArray array];
    for (NSUInteger x = 0; x < mediaCount; x++) {
        VLCMedia *media = [mediaList mediaAtIndex:x];
        NSString *mediaTitle;
        if (media.parsedStatus == VLCMediaParsedStatusDone) {
            mediaTitle = [media metadataForKey:VLCMetaInformationTitle];
        } else {
            mediaTitle = media.url.lastPathComponent;
        }

        NSDictionary *mediaDict = @{ @"id" : media.url.absoluteString,
                                     @"title" : mediaTitle,
                                     @"duration" : @(media.length.intValue) };
        [retArray addObject:@{ @"media" : mediaDict }];
    }
    [mediaList unlock];

    NSError *error;
    NSData *returnData = [NSJSONSerialization dataWithJSONObject:retArray options:0 error:&error];
    if (error != nil) {
        APLog(@"JSON serialization failed %@", error);
        return [[HTTPErrorResponse alloc] initWithErrorCode:500];
    }

    return [[HTTPDataResponse alloc] initWithData:returnData];
}
#endif

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/upload.json"])
        return [self _httpPOSTresponseUploadJSON];

#if TARGET_OS_IOS
    if ([path hasPrefix:@"/download/"]) {
        return [self _httpGETDownloadForPath:path];
    }
    if ([path hasPrefix:@"/Thumbnail/"]) {
        return [self _httpGETThumbnailForPath:path];
    }
#else
    if ([path hasPrefix:@"/playing"]) {
        return [self _HTTPGETPlaying];
    }
    if ([path hasPrefix:@"/playlist"]) {
        return [self _HTTPGETPlaylist];
    }
    if ([path hasPrefix:@"/web_resources.js"]) {
        return [self _HTTPGETwebResources];
    }
#endif

    NSString *filePath = [self filePathForURI:path];
    NSString *documentRoot = [config documentRoot];
    NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];

    if ([relativePath isEqualToString:@"/index.html"] || [relativePath isEqualToString:@"/libMediaVLC.xml"]) {
        return [self _httpGETLibraryForPath:path];
    } else if ([relativePath isEqualToString:@"/style.css"]) {
        return [self _httpGETCSSForPath:path];
    }

    return [super httpResponseForMethod:method URI:path];
}

#if TARGET_OS_TV
- (WebSocket *)webSocketForURI:(NSString *)path
{
    return [[VLCPlayerControlWebSocket alloc] initWithRequest:request socket:asyncSocket];
}
#endif

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
    // set up mime parser
    NSString* boundary = [request headerField:@"boundary"];
    _parser = [[MultipartFormDataParser alloc] initWithBoundary:boundary formEncoding:NSUTF8StringEncoding];
    _parser.delegate = self;

    APLog(@"expecting file of size %lli kB", contentLength / 1024);
    _contentLength = contentLength;
}

- (void)processBodyData:(NSData *)postDataChunk
{
    /* append data to the parser. It will invoke callbacks to let us handle
     * parsed data. */
    [_parser appendData:postDataChunk];

    _receivedContent += postDataChunk.length;

    long long percentage = ((_receivedContent * 100) / _contentLength);
    APLog(@"received %lli kB (%lli %%)", _receivedContent / 1024, percentage);
#if TARGET_OS_TV
        if (percentage >= 10) {
            [self performSelectorOnMainThread:@selector(startPlaybackOfPath:) withObject:_filepath waitUntilDone:NO];
        }
#endif
}

#if TARGET_OS_TV
- (void)startPlaybackOfPath:(NSString *)path
{
    APLog(@"Starting playback of %@", path);
    if (_receivedFiles == nil)
        _receivedFiles = [[NSMutableArray alloc] init];

    if ([_receivedFiles containsObject:path])
        return;

    [_receivedFiles addObject:path];

    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
    VLCMediaList *mediaList = vpc.mediaList;

    if (!mediaList) {
        mediaList = [[VLCMediaList alloc] init];
    }

    [mediaList addMedia:[VLCMedia mediaWithURL:[NSURL fileURLWithPath:path]]];

    if (!vpc.mediaList) {
        [vpc playMediaList:mediaList firstIndex:0 subtitlesFilePath:nil];
    }

    VLCFullscreenMovieTVViewController *movieVC = [VLCFullscreenMovieTVViewController fullscreenMovieTVViewController];

    if (![movieVC isBeingPresented]) {
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:movieVC
                                                                                     animated:YES
                                                                                   completion:nil];
    }
}
#endif

//-----------------------------------------------------------------
#pragma mark multipart form data parser delegate


- (void)processStartOfPartWithHeader:(MultipartMessageHeader*) header
{
    /* in this sample, we are not interested in parts, other then file parts.
     * check content disposition to find out filename */

    MultipartMessageHeaderField* disposition = (header.fields)[@"Content-Disposition"];
    NSString* filename = (disposition.params)[@"filename"];

    if ((nil == filename) || [filename isEqualToString: @""]) {
        // it's either not a file part, or
        // an empty form sent. we won't handle it.
        return;
    }

    // create the path where to store the media temporarily
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *uploadDirPath = [searchPaths.firstObject
                               stringByAppendingPathComponent:kVLCHTTPUploadDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDir = YES;
    if (![fileManager fileExistsAtPath:uploadDirPath isDirectory:&isDir])
        [fileManager createDirectoryAtPath:uploadDirPath withIntermediateDirectories:YES attributes:nil error:nil];

    _filepath = [uploadDirPath stringByAppendingPathComponent: filename];

    NSNumber *freeSpace = [[UIDevice currentDevice] VLCFreeDiskSpace];
    if (_contentLength >= freeSpace.longLongValue) {
        /* avoid deadlock since we are on a background thread */
        [self performSelectorOnMainThread:@selector(notifyUserAboutEndOfFreeStorage:) withObject:filename waitUntilDone:NO];
        [self handleResourceNotFound];
        [self stop];
        return;
    }

    APLog(@"Saving file to %@", _filepath);
    if (![fileManager createDirectoryAtPath:[_filepath stringByDeletingLastPathComponent]
                withIntermediateDirectories:true attributes:nil error:nil])
        APLog(@"Could not create directory at path: %@", _filepath);

    if (![fileManager createFileAtPath:_filepath contents:nil attributes:nil])
        APLog(@"Could not create file at path: %@", _filepath);

    _storeFile = [NSFileHandle fileHandleForWritingAtPath:_filepath];

    VLCActivityManager *activityManager = [VLCActivityManager defaultManager];
    [activityManager networkActivityStarted];
    [activityManager disableIdleTimer];
}

- (void)notifyUserAboutEndOfFreeStorage:(NSString *)filename
{
#if TARGET_OS_IOS
    [VLCAlertViewController alertViewManagerWithTitle:NSLocalizedString(@"DISK_FULL", nil)
                                         errorMessage:[NSString stringWithFormat:
                                                       NSLocalizedString(@"DISK_FULL_FORMAT", nil),
                                                       filename,
                                                       [[UIDevice currentDevice] model]]
                                       viewController:[UIApplication sharedApplication].keyWindow.rootViewController];
#else
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"DISK_FULL", nil)
                                                                             message:[NSString stringWithFormat:
                                                                                      NSLocalizedString(@"DISK_FULL_FORMAT", nil),
                                                                                      filename,
                                                                                      [[UIDevice currentDevice] model]]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"BUTTON_CANCEL", nil)
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
#endif
}

- (void)processContent:(NSData*)data WithHeader:(MultipartMessageHeader*) header
{
    // here we just write the output from parser to the file.
    if (_storeFile) {
        @try {
            [_storeFile writeData:data];
        }
        @catch (NSException *exception) {
            APLog(@"File to write further data because storage is full.");
            [_storeFile closeFile];
            _storeFile = nil;
            /* don't block */
            [self performSelector:@selector(stop) withObject:nil afterDelay:0.1];
        }
    }

}

- (void)processEndOfPartWithHeader:(MultipartMessageHeader*)header
{
    // as the file part is over, we close the file.
    APLog(@"closing file");
    [_storeFile closeFile];
    _storeFile = nil;
}

- (BOOL)shouldDie
{
    if (_filepath) {
        if (_filepath.length > 0) {
            [[VLCHTTPUploaderController sharedInstance] moveFileFrom:_filepath];

#if TARGET_OS_TV
            [_receivedFiles removeObject:_filepath];
#endif
        }
    }
    return [super shouldDie];
}

#pragma mark subtitle

- (NSMutableArray *)_listOfSubtitles
{
    NSMutableArray *listOfSubtitles = [[NSMutableArray alloc] init];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    NSString *filePath;
    NSUInteger count = allFiles.count;
    for (NSUInteger i = 0; i < count; i++) {
        filePath = [[NSString stringWithFormat:@"%@/%@", documentsDirectory, allFiles[i]] stringByReplacingOccurrencesOfString:@"file://"withString:@""];
        if ([filePath isSupportedSubtitleFormat])
            [listOfSubtitles addObject:filePath];
    }
    return listOfSubtitles;
}

- (NSString *)_checkIfSubtitleWasFound:(NSString *)filePath
{
    NSString *subtitlePath;
    NSString *fileSub;
    NSString *currentPath;

    NSString *fileName = [[filePath lastPathComponent] stringByDeletingPathExtension];
    if (fileName == nil)
        return nil;

    NSMutableArray *listOfSubtitles = [self _listOfSubtitles];
    NSUInteger count = listOfSubtitles.count;

    for (NSUInteger i = 0; i < count; i++) {
        currentPath = listOfSubtitles[i];
        fileSub = [NSString stringWithFormat:@"%@", currentPath];
        if ([fileSub rangeOfString:fileName].location != NSNotFound)
            subtitlePath = currentPath;
    }
    return subtitlePath;
}

@end
