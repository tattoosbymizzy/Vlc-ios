/*****************************************************************************
 * VLCEditController.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

protocol VLCEditControllerDelegate: class {
    func editController(editController: VLCEditController, cellforItemAt indexPath: IndexPath) -> MediaEditCell?
    func editController(editController: VLCEditController, present viewController: UIViewController)
}

class VLCEditController: UIViewController {
    private var selectedCellIndexPaths = Set<IndexPath>()
    private let model: MediaLibraryBaseModel
    private let mediaLibraryService: MediaLibraryService
    private lazy var addToPlaylistViewController: AddToPlaylistViewController = {
        var addToPlaylistViewController = AddToPlaylistViewController(playlists: mediaLibraryService.playlists())
        addToPlaylistViewController.delegate = self
        return addToPlaylistViewController
    }()

    weak var delegate: VLCEditControllerDelegate?

    override func loadView() {
        let editToolbar = VLCEditToolbar(category: model)
        editToolbar.delegate = self
        self.view = editToolbar
    }

    init(mediaLibraryService: MediaLibraryService, model: MediaLibraryBaseModel) {
        self.mediaLibraryService = mediaLibraryService
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resetSelections() {
        selectedCellIndexPaths.removeAll(keepingCapacity: false)
    }
}

// MARK: - Helpers

private extension VLCEditController {
    private struct TextFieldAlertInfo {
        var alertTitle: String
        var alertDescription: String
        var placeHolder: String
        var confirmActionTitle: String

        init(alertTitle: String = "",
             alertDescription: String = "",
             placeHolder: String = "",
             confirmActionTitle: String = NSLocalizedString("BUTTON_DONE", comment: "")) {
            self.alertTitle = alertTitle
            self.alertDescription = alertDescription
            self.placeHolder = placeHolder
            self.confirmActionTitle = confirmActionTitle
        }
    }

    private func presentTextFieldAlert(with info: TextFieldAlertInfo,
                                       completionHandler: @escaping (String) -> Void) {
        let alertController = UIAlertController(title: info.alertTitle,
                                                message: info.alertDescription,
                                                preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            textField in
            textField.placeholder = info.placeHolder
        })

        let cancelButton = UIAlertAction(title: NSLocalizedString("BUTTON_CANCEL", comment: ""),
                                         style: .default)


        let confirmAction = UIAlertAction(title: info.confirmActionTitle, style: .default) {
            [weak alertController] _ in
            guard let alertController = alertController,
                let textField = alertController.textFields?.first else { return }
            completionHandler(textField.text ?? "")
        }

        alertController.addAction(cancelButton)
        alertController.addAction(confirmAction)

        present(alertController, animated: true, completion: nil)
    }

    private func createPlaylist(_ name: String) {
        guard let playlist = mediaLibraryService.createPlaylist(with: name) else {
            assertionFailure("MediaModel: createPlaylist: Failed to create a playlist.")
            DispatchQueue.main.async {
                VLCAlertViewController.alertViewManager(title: NSLocalizedString("ERROR_PLAYLIST_CREATION",
                                                                                 comment: ""),
                                                        viewController: self)
            }
            return
        }

        // In the case of Video, Tracks
        if let files = model.anyfiles as? [VLCMLMedia] {
            for index in selectedCellIndexPaths where index.row < files.count {
                playlist.appendMedia(withIdentifier: files[index.row].identifier())
            }
        } else if let mediaCollectionArray = model.anyfiles as? [MediaCollectionModel] {
            for index in selectedCellIndexPaths where index.row < mediaCollectionArray.count {
                guard let tracks = mediaCollectionArray[index.row].files() else {
                    assertionFailure("EditController: Fail to retrieve tracks.")
                    DispatchQueue.main.async {
                        VLCAlertViewController.alertViewManager(title: NSLocalizedString("ERROR_PLAYLIST_TRACKS",
                                                                                         comment: ""),
                                                                viewController: self)
                    }
                    return
                }
                tracks.forEach() {
                    playlist.appendMedia(withIdentifier: $0.identifier())
                }
            }
        }
        selectedCellIndexPaths.removeAll()
    }
}

// MARK: - VLCEditToolbarDelegate

extension VLCEditController: VLCEditToolbarDelegate {
    func addToNewPlaylist() {
        let alertInfo = TextFieldAlertInfo(alertTitle: NSLocalizedString("PLAYLISTS", comment: ""),
                                           placeHolder: NSLocalizedString("PLAYLIST_PLACEHOLDER",
                                                                          comment: ""))
        presentTextFieldAlert(with: alertInfo) {
            [unowned self] text -> Void in
            guard text != "" else {
                DispatchQueue.main.async {
                    VLCAlertViewController.alertViewManager(title: NSLocalizedString("ERROR_EMPTY_NAME",
                                                                                     comment: ""),
                                                            viewController: self)
                }
                return
            }
            self.createPlaylist(text)
        }
    }

    func editToolbarDidAddToPlaylist(_ editToolbar: VLCEditToolbar) {
        if !mediaLibraryService.playlists().isEmpty && !selectedCellIndexPaths.isEmpty {
            addToPlaylistViewController.playlists = mediaLibraryService.playlists()
            delegate?.editController(editController: self,
                                     present: addToPlaylistViewController)
        } else {
            addToNewPlaylist()
        }
    }

    func editToolbarDidDelete(_ editToolbar: VLCEditToolbar) {
        var objectsToDelete = [VLCMLObject]()

        for indexPath in selectedCellIndexPaths {
            objectsToDelete.append(model.anyfiles[indexPath.row])
        }

        let cancelButton = VLCAlertButton(title: NSLocalizedString("BUTTON_CANCEL", comment: ""))
        let deleteButton = VLCAlertButton(title: NSLocalizedString("BUTTON_DELETE", comment: ""),
                                          style: .destructive,
                                          action: {
                                            [weak self] action in
                                            self?.model.delete(objectsToDelete)
                                            self?.selectedCellIndexPaths.removeAll()
        })

        VLCAlertViewController.alertViewManager(title: NSLocalizedString("DELETE_TITLE", comment: ""),
                                                errorMessage: NSLocalizedString("DELETE_MESSAGE", comment: ""),
                                                viewController: (UIApplication.shared.keyWindow?.rootViewController)!,
                                                buttonsAction: [cancelButton,
                                                                deleteButton])
    }

    func editToolbarDidShare(_ editToolbar: VLCEditToolbar, presentFrom button: UIButton) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        let rootViewController = UIApplication.shared.keyWindow?.rootViewController
        guard let controller = VLCActivityViewControllerVendor.activityViewController(forFiles: fileURLsFromSelection(), presenting: button, presenting: rootViewController) else {
            UIApplication.shared.endIgnoringInteractionEvents()
            return
        }
        controller.popoverPresentationController?.sourceView = editToolbar
        rootViewController?.present(controller, animated: true) {
            UIApplication.shared.endIgnoringInteractionEvents()
        }
    }

    func fileURLsFromSelection() -> [URL] {
        var fileURLS = [URL]()
        for indexPath in selectedCellIndexPaths {
            let file = model.anyfiles[indexPath.row]
            if let collection = file as? MediaCollectionModel,
                let files = collection.files() {
                files.forEach {
                    if let mainFile = $0.mainFile() {
                        fileURLS.append(mainFile.mrl)
                    }
                }
            } else if let media = file as? VLCMLMedia, let mainFile = media.mainFile() {
                fileURLS.append(mainFile.mrl)
            } else {
                assertionFailure("we're trying to share something that doesn't have an mrl")
                return fileURLS
            }
        }
        return fileURLS
    }

    func editToolbarDidRename(_ editToolbar: VLCEditToolbar) {
        // FIXME: Multiple renaming of files(multiple alert can get unfriendly if too many files)
        for indexPath in selectedCellIndexPaths {
            if let media = model.anyfiles[indexPath.row] as? VLCMLMedia {
                // Not using VLCAlertViewController to have more customization in text fields
                let alertInfo = TextFieldAlertInfo(alertTitle: String(format: NSLocalizedString("RENAME_MEDIA_TO", comment: ""), media.title),
                                                   placeHolder: NSLocalizedString("RENAME_PLACEHOLDER", comment: ""),
                                                   confirmActionTitle: NSLocalizedString("BUTTON_RENAME", comment: ""))
                presentTextFieldAlert(with: alertInfo, completionHandler: {
                    [weak self] text -> Void in
                    guard text != "" else {
                        VLCAlertViewController.alertViewManager(title: NSLocalizedString("ERROR_RENAME_FAILED", comment: ""),
                                                                errorMessage: NSLocalizedString("ERROR_EMPTY_NAME", comment: ""),
                                                                viewController: (UIApplication.shared.keyWindow?.rootViewController)!)
                        return
                    }
                    media.updateTitle(text)
                    if let strongself = self {
                        strongself.delegate?.editController(editController: strongself, cellforItemAt: indexPath)?.isChecked = false
                    }
                })
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension VLCEditController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return model.anyfiles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let editCell = (model as? EditableMLModel)?.editCellType() else {
            assertionFailure("The category either doesn't implement EditableMLModel or doesn't have a editcellType defined")
            return UICollectionViewCell()
        }
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: editCell.defaultReuseIdentifier,
                                                         for: indexPath) as? MediaEditCell {
            cell.media = model.anyfiles[indexPath.row]
            cell.isChecked = selectedCellIndexPaths.contains(indexPath)
            return cell
        } else {
            assertionFailure("We couldn't dequeue a reusable cell, the cell might not be registered or is not a MediaEditCell")
            return UICollectionViewCell()
        }
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard let collectionModel = model as? CollectionModel, let playlist = collectionModel.mediaCollection as? VLCMLPlaylist else {
            assertionFailure("can Move should've been false")
            return
        }
        playlist.moveMedia(fromPosition: UInt32(sourceIndexPath.row), toDestination: UInt32(destinationIndexPath.row))
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        if let collectionModel = model as? CollectionModel, collectionModel.mediaCollection is VLCMLPlaylist {
            return true
        }
        return false
    }
}

// MARK: - UICollectionViewDelegate

extension VLCEditController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? MediaEditCell {
            cell.isChecked = !cell.isChecked
            if cell.isChecked {
                // cell selected, saving indexPath
                selectedCellIndexPaths.insert(indexPath)
            } else {
                selectedCellIndexPaths.remove(indexPath)
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension VLCEditController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let contentInset = collectionView.contentInset
        // FIXME: 5 should be cell padding, but not usable maybe static?
        let insetToRemove = contentInset.left + contentInset.right + (5 * 2)
        var width = collectionView.frame.width
        if #available(iOS 11.0, *) {
            width = collectionView.safeAreaLayoutGuide.layoutFrame.width
        }
        return CGSize(width: width - insetToRemove, height: MediaEditCell.height)
    }
}

extension VLCEditController: AddToPlaylistViewControllerDelegate {
    func addToPlaylistViewController(_ addToPlaylistViewController: AddToPlaylistViewController,
                                     didSelectPlaylist playlist: VLCMLPlaylist) {
        let files = model.anyfiles
        for index in selectedCellIndexPaths where index.row < files.count {
            if !playlist.appendMedia(withIdentifier: files[index.row].identifier()) {
                assertionFailure("VLCEditController: AddToPlaylistViewControllerDelegate: Failed to add item.")
            }
        }
        addToPlaylistViewController.dismiss(animated: true, completion: nil)
    }

    func addToPlaylistViewController(_ addToPlaylistViewController: AddToPlaylistViewController,
                                     newPlaylistWithName name: String) {
        createPlaylist(name)
        addToPlaylistViewController.dismiss(animated: true, completion: nil)
    }
}
