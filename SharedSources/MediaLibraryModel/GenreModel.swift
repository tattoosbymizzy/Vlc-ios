/*****************************************************************************
 * GenreModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

class GenreModel: MLBaseModel {
    typealias MLType = VLCMLGenre

    var sortModel = SortModel([.alpha])

    var updateView: (() -> Void)?

    var files = [VLCMLGenre]()

    var cellType: BaseCollectionViewCell.Type { return GenreCollectionViewCell.self }

    var medialibrary: MediaLibraryService

    var indicatorName: String = NSLocalizedString("GENRES", comment: "")

    required init(medialibrary: MediaLibraryService) {
        self.medialibrary = medialibrary
        medialibrary.addObserver(self)
        files = medialibrary.genres()
    }

    func append(_ item: VLCMLGenre) {
        files.append(item)
    }

    func delete(_ items: [VLCMLObject]) {
        preconditionFailure("GenreModel: Cannot delete genre")
    }
}

// MARK: - Sort

extension GenreModel {
    func sort(by criteria: VLCMLSortingCriteria) {
        files = medialibrary.genres(sortingCriteria: criteria)
        sortModel.currentSort = criteria
        updateView?()
    }
}

extension GenreModel: MediaLibraryObserver {
    func medialibrary(_ medialibrary: MediaLibraryService, didAddGenres genres: [VLCMLGenre]) {
        genres.forEach({ append($0) })
        updateView?()
    }
}

// MARK: - Edit
extension GenreModel: EditableMLModel {
    func editCellType() -> BaseCollectionViewCell.Type {
        return MediaEditCell.self
    }
}
extension VLCMLGenre {
    @objc func numberOfTracksString() -> String {
        let numberOftracks = numberOfTracks()
        if numberOftracks != 1 {
            return String(format: NSLocalizedString("TRACKS", comment: ""), numberOftracks)
        }
        return String(format: NSLocalizedString("TRACK", comment: ""), numberOftracks)
    }
}

extension VLCMLGenre: MediaCollectionModel {
    func files() -> [VLCMLMedia] {
        return []
    }
}
