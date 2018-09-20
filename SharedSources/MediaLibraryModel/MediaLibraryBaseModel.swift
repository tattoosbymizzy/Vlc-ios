/*****************************************************************************
 * MediaLibraryBaseModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// Expose a "shadow" version without associatedType in order to use it as a type
protocol MediaLibraryBaseModel {
    init(medialibrary: VLCMediaLibraryManager)

    var anyfiles: [VLCMLObject] { get }

    var updateView: (() -> Void)? { get set }

    var indicatorName: String { get }
    var cellType: BaseCollectionViewCell.Type { get }

    func append(_ item: VLCMLObject)
    func delete(_ items: [VLCMLObject])
    func sort(by criteria: VLCMLSortingCriteria)
}

protocol MLBaseModel: AnyObject, MediaLibraryBaseModel {
    associatedtype MLType where MLType: VLCMLObject

    init(medialibrary: VLCMediaLibraryManager)

    var files: [MLType] { get set }

    var medialibrary: VLCMediaLibraryManager { get }

    var updateView: (() -> Void)? { get set }

    var indicatorName: String { get }

    func append(_ item: MLType)
    // FIXME: Ideally items should be MLType but Swift isn't happy so it will always fail
    func delete(_ items: [VLCMLObject])
    func sort(by criteria: VLCMLSortingCriteria)
}

extension MLBaseModel {

    var anyfiles: [VLCMLObject] {
        return files
    }

    func append(_ item: VLCMLObject) {
        fatalError()
    }

    func delete(_ items: [VLCMLObject]) {
        fatalError()
    }

    func sort(by criteria: VLCMLSortingCriteria) {
        fatalError()
    }
}
