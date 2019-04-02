//
//  CollectionModel.swift
//  VLC-iOS
//
//  Created by Carola Nitz on 08.03.19.
//  Copyright © 2019 VideoLAN. All rights reserved.
//

import Foundation

class CollectionModel: MLBaseModel {

    typealias MLType = VLCMLMedia // could be anything
    required init(medialibrary: MediaLibraryService) {
        preconditionFailure("")
    }

    required init(mediaService: MediaLibraryService, mediaCollection: MediaCollectionModel) {
        self.medialibrary = mediaService
        files = mediaCollection.files()
    }

    func append(_ item: VLCMLMedia) {
        files.append(item)
    }

    var medialibrary: MediaLibraryService
    var updateView: (() -> Void)?

    var files = [VLCMLMedia]()

    var cellType: BaseCollectionViewCell.Type { return AudioCollectionViewCell.self } //TODO: this approach will not work here because playlists can contain audio or videocells

    var indicatorName: String = NSLocalizedString("Collections", comment: "")

    func delete(_ items: [VLCMLObject]) {
       assertionFailure("still needs implementation")
    }
}

// MARK: - Edit
extension CollectionModel: EditableMLModel {
    func editCellType() -> BaseCollectionViewCell.Type {
        return MediaEditCell.self
    }
}

