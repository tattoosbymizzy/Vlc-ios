/*****************************************************************************
 * AlbumModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

class AlbumModel: MLBaseModel {
    typealias MLType = VLCMLAlbum

    var sortModel = SortModel([.alpha, .duration, .releaseDate, .trackNumber])

    var updateView: (() -> Void)?

    var files = [VLCMLAlbum]()

    var cellType: BaseCollectionViewCell.Type { return MediaCollectionViewCell.self }

    var medialibrary: MediaLibraryService

    var indicatorName: String = NSLocalizedString("ALBUMS", comment: "")

    required init(medialibrary: MediaLibraryService) {
        self.medialibrary = medialibrary
        medialibrary.addObserver(self)
        files = medialibrary.albums()
    }

    func append(_ item: VLCMLAlbum) {
        files.append(item)
    }

    func delete(_ items: [VLCMLObject]) {
        preconditionFailure("AlbumModel: Albums can not be deleted, they disappear when their last title got deleted")
    }
}

// MARK: - Sort

extension AlbumModel {
    func sort(by criteria: VLCMLSortingCriteria) {
        files = medialibrary.albums(sortingCriteria: criteria)
        sortModel.currentSort = criteria
        updateView?()
    }
}

// MARK: - Edit

extension AlbumModel: EditableMLModel {
    func editCellType() -> BaseCollectionViewCell.Type {
        return MediaEditCell.self
    }
}

// MARK: - MediaLibraryObserver

extension AlbumModel: MediaLibraryObserver {
    func medialibrary(_ medialibrary: MediaLibraryService, didAddAlbums albums: [VLCMLAlbum]) {
        albums.forEach({ append($0) })
        updateView?()
    }
}

extension VLCMLAlbum: MediaCollectionModel {
    func sortModel() -> SortModel? {
        return nil
    }

    func files() -> [VLCMLMedia]? {
        return tracks
    }

    func title() -> String? {
        return title
    }
}
