/*****************************************************************************
 * ArtistModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

class ArtistModel: MLBaseModel {
    typealias MLType = VLCMLArtist

    var sortModel = SortModel([.alpha])

    var updateView: (() -> Void)?

    var files = [VLCMLArtist]()

    var cellType: BaseCollectionViewCell.Type { return MediaCollectionViewCell.self }

    var medialibrary: MediaLibraryService

    var indicatorName: String = NSLocalizedString("ARTISTS", comment: "")

    required init(medialibrary: MediaLibraryService) {
        self.medialibrary = medialibrary
        medialibrary.addObserver(self)
        files = medialibrary.artists()
    }

    func append(_ item: VLCMLArtist) {
        files.append(item)
    }

    func delete(_ items: [VLCMLObject]) {
        preconditionFailure("ArtistModel: Artists can not be deleted, they disappear when their last title got deleted")
    }
}

// MARK: - Edit
extension ArtistModel: EditableMLModel {
    func editCellType() -> BaseCollectionViewCell.Type {
        return MediaEditCell.self
    }
}

// MARK: - Sort

extension ArtistModel {
    func sort(by criteria: VLCMLSortingCriteria) {
        files = medialibrary.artists(sortingCriteria: criteria)
        sortModel.currentSort = criteria
        updateView?()
    }
}

// MARK: - MediaLibraryObserver

extension ArtistModel: MediaLibraryObserver {
    func medialibrary(_ medialibrary: MediaLibraryService, didAddArtists artists: [VLCMLArtist]) {
        artists.forEach({ append($0) })
        updateView?()
    }
}

extension VLCMLArtist: MediaCollectionModel {

    func sortModel() -> SortModel? {
        return SortModel([.alpha])
    }

    func files() -> [VLCMLMedia]? {
        return tracks()
    }

    func title() -> String? {
        return name
    }
}

extension VLCMLArtist {
    func numberOfTracksString() -> String {
        let tracksString = tracks()?.count == 1 ? NSLocalizedString("TRACK", comment: "") : NSLocalizedString("TRACKS", comment: "")
        return String(format: tracksString, tracks()?.count ?? 0)
    }
}
