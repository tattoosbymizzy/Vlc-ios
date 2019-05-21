/*****************************************************************************
 * MediaCateogoryViewController.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Carola Nitz <nitz.carola # gmail.com>
 *          Mike JS. Choi <mkchoi212 # icloud.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

class VLCMediaCategoryViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UISearchResultsUpdating, UISearchControllerDelegate, IndicatorInfoProvider {

    var model: MediaLibraryBaseModel

    private var services: Services
    private var searchController: UISearchController?
    private let searchDataSource = VLCLibrarySearchDisplayDataSource()
    private var rendererButton: UIButton
    private lazy var editController: VLCEditController = {
        let editController = VLCEditController(mediaLibraryService:services.medialibraryService, model: model)
        editController.delegate = self
        return editController
    }()

    private var editToolbarConstraint: NSLayoutConstraint?
    private var cachedCellSize = CGSize.zero
    private var toSize = CGSize.zero
    private var longPressGesture: UILongPressGestureRecognizer!

//    @available(iOS 11.0, *)
//    lazy var dragAndDropManager: VLCDragAndDropManager = { () -> VLCDragAndDropManager<T> in
//        VLCDragAndDropManager<T>(subcategory: VLCMediaSubcategories<>)
//    }()

    @objc private lazy var sortActionSheet: ActionSheet = {
        let actionSheet = ActionSheet()
        actionSheet.delegate = self
        actionSheet.dataSource = self
        actionSheet.modalPresentationStyle = .custom
        actionSheet.setAction { [weak self] item in
            guard let sortingCriteria = item as? VLCMLSortingCriteria else {
                return
            }
            self?.model.sort(by: sortingCriteria)
            self?.sortActionSheet.removeActionSheet()
        }
        return actionSheet
    }()


    lazy var emptyView: VLCEmptyLibraryView = {
        let name = String(describing: VLCEmptyLibraryView.self)
        let nib = Bundle.main.loadNibNamed(name, owner: self, options: nil)
        guard let emptyView = nib?.first as? VLCEmptyLibraryView else { fatalError("Can't find nib for \(name)") }
        return emptyView
    }()

    let editCollectionViewLayout: UICollectionViewFlowLayout = {
        let editCollectionViewLayout = UICollectionViewFlowLayout()
        editCollectionViewLayout.minimumLineSpacing = 1
        editCollectionViewLayout.minimumInteritemSpacing = 0
        return editCollectionViewLayout
    }()

    @available(*, unavailable)
    init() {
        fatalError()
    }

    init(services: Services, model: MediaLibraryBaseModel) {
        self.services = services
        self.model = model
        self.rendererButton = services.rendererDiscovererManager.setupRendererButton()
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
        if let collection = model as? CollectionModel {
            title = collection.mediaCollection.title()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: .VLCThemeDidChangeNotification, object: nil)
        navigationItem.rightBarButtonItems = [editButtonItem, UIBarButtonItem(customView: rendererButton)]
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PresentationTheme.current.colors.statusBarStyle
    }

    @objc func reloadData() {
        DispatchQueue.main.async {
            [weak self] in
            self?.collectionView?.reloadData()
            self?.updateUIForContent()
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder: ) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupSearchController()
        setupEditToolbar()
        _ = (MLMediaLibrary.sharedMediaLibrary() as! MLMediaLibrary).libraryDidAppear()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let manager = services.rendererDiscovererManager
        if manager.discoverers.isEmpty {
            // Either didn't start or stopped before
            manager.start()
        }
        manager.presentingViewController = self
    }

    @objc func themeDidChange() {
        collectionView?.backgroundColor = PresentationTheme.current.colors.background
        editController.view.backgroundColor = PresentationTheme.current.colors.background
        setNeedsStatusBarAppearanceUpdate()
    }

    func setupEditToolbar() {
        editController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editController.view)
        var guide: LayoutAnchorContainer = view
        if #available(iOS 11.0, *) {
            guide = view.safeAreaLayoutGuide
        }
        editToolbarConstraint = editController.view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: VLCEditToolbar.height)
        NSLayoutConstraint.activate([
            editToolbarConstraint!,
            editController.view.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            editController.view.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            editController.view.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reloadData()
    }

    func isEmptyCollectionView() -> Bool {
        return collectionView?.numberOfItems(inSection: 0) == 0
    }

    func updateUIForContent() {
        let isEmpty = isEmptyCollectionView()

        if isEmpty {
            collectionView?.setContentOffset(.zero, animated: false)
        }
        collectionView?.backgroundView = isEmpty ? emptyView : nil
        
        if #available(iOS 11.0, *) {
            navigationItem.searchController = isEmpty ? nil : searchController
        } else {
            navigationItem.titleView = isEmpty ? nil : searchController?.searchBar
        }
    }

    // MARK: Renderer

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        cachedCellSize = .zero
        toSize = size
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    // MARK: - Edit

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        // might have an issue if the old datasource was search
        // Most of the edit logic is handled inside editController
        collectionView?.dataSource = editing ? editController : self
        collectionView?.delegate = editing ? editController : self

        editController.resetSelections()
        displayEditToolbar()
        let layoutToBe = editing ? editCollectionViewLayout : UICollectionViewFlowLayout()
        collectionView?.setCollectionViewLayout(layoutToBe, animated: false, completion: {
            [weak self] finished in
            guard finished else {
                assertionFailure("VLCMediaSubcategoryViewController: Edit layout transition failed.")
                return
            }
            self?.reloadData()
        })
    }

    private func displayEditToolbar() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.editToolbarConstraint?.constant = self?.isEditing == true ? 0 : VLCEditToolbar.height
            self?.view.layoutIfNeeded()
            self?.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self?.isEditing == true ? VLCEditToolbar.height : 0, right: 0)
        }
    }

    // MARK: - Search

    func updateSearchResults(for searchController: UISearchController) {
        searchDataSource.shouldReloadTable(forSearch: searchController.searchBar.text, searchableFiles: model.anyfiles)
        collectionView?.reloadData()
    }

    func didPresentSearchController(_ searchController: UISearchController) {
        collectionView?.dataSource = searchDataSource
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        collectionView?.dataSource = self
    }

    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title:model.indicatorName)
    }

    // MARK: - UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return model.anyfiles.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let mediaCell = collectionView.dequeueReusableCell(withReuseIdentifier:model.cellType.defaultReuseIdentifier, for: indexPath) as? BaseCollectionViewCell else {
            assertionFailure("you forgot to register the cell or the cell is not a subclass of BaseCollectionViewCell")
            return UICollectionViewCell()
        }
        let mediaObject = model.anyfiles[indexPath.row]
        if let media = mediaObject as? VLCMLMedia {
            assert(media.mainFile() != nil, "The mainfile is nil")
            mediaCell.media = media.mainFile() != nil ? media : nil
        } else {
            mediaCell.media = mediaObject
        }
        return mediaCell
    }

    // MARK: - UICollectionViewDelegate
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let media = model.anyfiles[indexPath.row] as? VLCMLMedia {
            play(media: media)
            createSpotlightItem(media: media)
        } else if let mediaCollection = model.anyfiles[indexPath.row] as? MediaCollectionModel {
            let collectionViewController = VLCCollectionCategoryViewController(services, mediaCollection: mediaCollection)
            navigationController?.pushViewController(collectionViewController, animated: true)
        }
    }

    func createSpotlightItem(media: VLCMLMedia) {
        if KeychainCoordinator.passcodeLockEnabled {
            return
        }
        userActivity = NSUserActivity(activityType: kVLCUserActivityPlaying)
        userActivity?.title = media.title
        userActivity?.contentAttributeSet = media.coreSpotlightAttributeSet()
        userActivity?.userInfo = ["playingmedia" : media.identifier()]
        userActivity?.isEligibleForSearch = true
        userActivity?.isEligibleForHandoff = true
        userActivity?.becomeCurrent()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension VLCMediaCategoryViewController {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if cachedCellSize == .zero {
            //For iOS 10 when rotating we take the value from willTransition to size, for the first layout pass that value is 0 though,
            //so we need the frame.size width. For rotation on iOS 11 this approach doesn't work because at the time when this is called
            //we don't have yet the updated safeare layout frame. This is addressed by relayouting from viewSafeAreaInsetsDidChange
            var toWidth = toSize.width != 0 ? toSize.width : collectionView.frame.size.width
            if #available(iOS 11.0, *) {
                toWidth = collectionView.safeAreaLayoutGuide.layoutFrame.width
            }
            cachedCellSize = model.cellType.cellSizeForWidth(toWidth)
        }
        return cachedCellSize
    }

    override func viewSafeAreaInsetsDidChange() {
        cachedCellSize = .zero
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: model.cellType.edgePadding, left: model.cellType.edgePadding, bottom: model.cellType.edgePadding, right: model.cellType.edgePadding)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return model.cellType.edgePadding
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return model.cellType.interItemPadding
    }

    func handleSort() {
        var currentSortIndex: Int = 0
        for (index, criteria) in
            model.sortModel.sortingCriteria.enumerated()
            where criteria == model.sortModel.currentSort {
                currentSortIndex = index
                break
        }
        present(sortActionSheet, animated: false) {
            [sortActionSheet, currentSortIndex] in
            sortActionSheet.collectionView.selectItem(at:
                IndexPath(row: currentSortIndex, section: 0), animated: false,
                                                    scrollPosition: .centeredVertically)
        }
    }
}

// MARK: VLCActionSheetDelegate

extension VLCMediaCategoryViewController: ActionSheetDelegate {
    func headerViewTitle() -> String? {
        return NSLocalizedString("HEADER_TITLE_SORT", comment: "")
    }

    // This provide the item to send to the selection action
    func itemAtIndexPath(_ indexPath: IndexPath) -> Any? {
        let enabledSortCriteria = model.sortModel.sortingCriteria

        if indexPath.row < enabledSortCriteria.count {
            return enabledSortCriteria[indexPath.row]
        }
        assertionFailure("VLCMediaCategoryViewController: VLCActionSheetDelegate: IndexPath out of range")
        return nil
    }
}

// MARK: VLCActionSheetDataSource

extension VLCMediaCategoryViewController: ActionSheetDataSource {
    func numberOfRows() -> Int {
        return model.sortModel.sortingCriteria.count
    }

    func actionSheet(collectionView: UICollectionView,
                     cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ActionSheetCell.identifier,
            for: indexPath) as? ActionSheetCell else {
                assertionFailure("VLCMediaCategoryViewController: VLCActionSheetDataSource: Unable to dequeue reusable cell")
                return UICollectionViewCell()
        }

        let sortingCriterias = model.sortModel.sortingCriteria

        guard indexPath.row < sortingCriterias.count else {
            assertionFailure("VLCMediaCategoryViewController: VLCActionSheetDataSource: IndexPath out of range")
            return cell
        }

        cell.name.text = String(describing: sortingCriterias[indexPath.row])
        return cell
    }
}

extension VLCMediaCategoryViewController: VLCEditControllerDelegate {
    func editController(editController: VLCEditController, cellforItemAt indexPath: IndexPath) -> MediaEditCell? {
        return collectionView.cellForItem(at: indexPath) as? MediaEditCell
    }

    func editController(editController: VLCEditController,
                        present viewController: UIViewController) {
        let newNavigationController = UINavigationController(rootViewController: viewController)
        navigationController?.present(newNavigationController, animated: true, completion: nil)
    }
}

private extension VLCMediaCategoryViewController {
    func setupCollectionView() {
        let cellNib = UINib(nibName: model.cellType.nibName, bundle: nil)
        collectionView?.register(cellNib, forCellWithReuseIdentifier: model.cellType.defaultReuseIdentifier)
        if let editCell = (model as? EditableMLModel)?.editCellType() {
            let editCellNib = UINib(nibName: editCell.nibName, bundle: nil)
            collectionView?.register(editCellNib, forCellWithReuseIdentifier: editCell.defaultReuseIdentifier)
        }
        collectionView?.backgroundColor = PresentationTheme.current.colors.background
        collectionView?.alwaysBounceVertical = true

        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongGesture(gesture:)))
        collectionView?.addGestureRecognizer(longPressGesture)
        if #available(iOS 11.0, *) {
            collectionView?.contentInsetAdjustmentBehavior = .always
            //            collectionView?.dragDelegate = dragAndDropManager
            //            collectionView?.dropDelegate = dragAndDropManager
        }
    }

    func setupSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.dimsBackgroundDuringPresentation = false
        searchController?.delegate = self
        if let textfield = searchController?.searchBar.value(forKey: "searchField") as? UITextField {
            if let backgroundview = textfield.subviews.first {
                backgroundview.backgroundColor = UIColor.white
                backgroundview.layer.cornerRadius = 10
                backgroundview.clipsToBounds = true
            }
        }
    }

    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {

        switch gesture.state {
        case .began:
            guard let selectedIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
                break
            }
            collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case .ended:
            collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }
}

// MARK: - Player

extension VLCMediaCategoryViewController {

    func play(media: VLCMLMedia) {
        VLCPlaybackController.sharedInstance().fullscreenSessionRequested = media.subtype() != .albumTrack
        if let collectionModel = model as? CollectionModel, collectionModel.mediaCollection is VLCMLPlaylist || collectionModel.mediaCollection is VLCMLAlbum {
            guard let index = collectionModel.files.index(of: media) else {
                return
            }
            VLCPlaybackController.sharedInstance().playMedia(at: index, fromCollection: collectionModel.files)
        } else {
            VLCPlaybackController.sharedInstance().play(media)
        }
    }
}

// MARK: - MediaLibraryModelView

extension VLCMediaCategoryViewController {
    func dataChanged() {
        reloadData()
    }
}
