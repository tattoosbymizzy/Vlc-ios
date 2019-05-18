/*****************************************************************************
 * MediaModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

protocol MediaModel: MLBaseModel where MLType == VLCMLMedia { }

extension MediaModel {
    func append(_ item: VLCMLMedia) {
        if !files.contains { $0 == item } {
            files.append(item)
        }
    }

    func delete(_ items: [VLCMLObject]) {
        do {
            for case let media as VLCMLMedia in items {
                if let mainFile = media.mainFile() {
                    try FileManager.default.removeItem(atPath: mainFile.mrl.path)
                }
            }
            medialibrary.reload()
        }
        catch let error as NSError {
            assertionFailure("MediaModel: Delete failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Helpers

extension VLCMLMedia {
    static func == (lhs: VLCMLMedia, rhs: VLCMLMedia) -> Bool {
        return lhs.identifier() == rhs.identifier()
    }
}
// MARK: - ViewModel
extension VLCMLMedia {
    @objc func mediaDuration() -> String {
        return String(format: "%@", VLCTime(int: Int32(duration())))
    }

    @objc func formatSize() -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(mainFile()?.size() ?? 0),
                                         countStyle: .file)
    }
}

// MARK: - CoreSpotlight

extension VLCMLMedia {
    func coreSpotlightAttributeSet() -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: "public.audiovisual-content")
        attributeSet.title = title
        attributeSet.metadataModificationDate = Date()
        attributeSet.addedDate = Date()
        attributeSet.duration = NSNumber(value: duration() / 1000)
        attributeSet.streamable = 0
        attributeSet.deliveryType = 0
        attributeSet.local = 1
        attributeSet.playCount = NSNumber(value: playCount())
        if isThumbnailGenerated() {
            attributeSet.thumbnailData = UIImage(contentsOfFile: thumbnail.path)?.jpegData(compressionQuality: 0.9)
        }
        attributeSet.codecs = codecs()
        attributeSet.languages = languages()
        if let audioTracks = audioTracks {
            for track in audioTracks {
                attributeSet.audioBitRate = NSNumber(value: track.bitrate())
                attributeSet.audioChannelCount = NSNumber(value: track.nbChannels())
                attributeSet.audioSampleRate = NSNumber(value: track.sampleRate())
            }
        }
        if let albumTrack = albumTrack {
            if let genre = albumTrack.genre {
                attributeSet.genre = genre.name
            }
            if let artist = albumTrack.artist {
                attributeSet.artist = artist.name
            }
            attributeSet.audioTrackNumber = NSNumber(value:albumTrack.trackNumber())
            if let album = albumTrack.album {
                attributeSet.artist = album.title
            }
        }

        return attributeSet
    }

    func codecs() -> [String] {
        var codecs = [String]()
        if let videoTracks = videoTracks {
            for track in videoTracks {
                codecs.append(track.codec)
            }
        }
        if let audioTracks = audioTracks {
            for track in audioTracks {
                codecs.append(track.codec)
            }
        }
        if let subtitleTracks = subtitleTracks {
            for track in subtitleTracks {
                codecs.append(track.codec)
            }
        }
        return codecs
    }

    func languages() -> [String] {
        var languages = [String]()

        if let videoTracks = videoTracks {
            for track in videoTracks where track.language != "" {
                languages.append(track.language)
            }
        }
        if let audioTracks = audioTracks {
            for track in audioTracks where track.language != "" {
                languages.append(track.language)
            }
        }
        if let subtitleTracks = subtitleTracks {
            for track in subtitleTracks where track.language != "" {
                languages.append(track.language)
            }
        }
        return languages
    }

    func updateCoreSpotlightEntry() {
        if !KeychainCoordinator.passcodeLockEnabled {
            let groupIdentifier = ProcessInfo.processInfo.environment["GROUP_IDENTIFIER"]
            let item = CSSearchableItem(uniqueIdentifier: "\(identifier())", domainIdentifier: groupIdentifier, attributeSet: coreSpotlightAttributeSet())
            CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
        }
    }
}
