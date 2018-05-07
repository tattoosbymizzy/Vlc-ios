/*****************************************************************************
 * MediaViewController.swift
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

@objc public protocol VLCMediaViewControllerDelegate: class {
    func mediaViewControllerDidSelectMediaObject(_ mediaViewController: VLCMediaViewController, mediaObject: NSManagedObject)
    func mediaViewControllerDidSelectSort(_ mediaViewController: VLCMediaViewController)
}

public class VLCMediaViewController: UICollectionViewController, UISearchResultsUpdating, UISearchControllerDelegate {
    private var services: Services
    private var mediaDatasourceAndDelegate: MediaDataSourceAndDelegate?
    private var searchController: UISearchController?
    private let searchDataSource = VLCLibrarySearchDisplayDataSource()
    private var rendererButton: UIButton

    public weak var delegate: VLCMediaViewControllerDelegate?

    @available(iOS 11.0, *)
    lazy var dragAndDropManager: VLCDragAndDropManager = {
        let dragAndDropManager = VLCDragAndDropManager()
        dragAndDropManager.delegate = services.mediaDataSource
        return dragAndDropManager
    }()
    
    lazy var emptyView: VLCEmptyLibraryView = {
        let name = String(describing: VLCEmptyLibraryView.self)
        let nib = Bundle.main.loadNibNamed(name, owner: self, options: nil)
        guard let emptyView = nib?.first as? VLCEmptyLibraryView else { fatalError("Can't find nib for \(name)") }
        emptyView.frame = view.bounds
        return emptyView
    }()

    @available(*, unavailable)
    init() {
        fatalError()
    }

    init(services: Services) {
        self.services = services
        self.rendererButton = services.rendererDiscovererManager.setupRendererButton()
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: .VLCThemeDidChangeNotification, object: nil)
    }

    @available(*, unavailable)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupSearchController()
        setupNavigationBar()
        setupRendererButton()
        _ = (MLMediaLibrary.sharedMediaLibrary() as! MLMediaLibrary).libraryDidAppear()
    }

    public override func viewWillAppear(_ animated: Bool) {
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
    }

    func setupCollectionView() {
        mediaDatasourceAndDelegate = MediaDataSourceAndDelegate(services: services)
        mediaDatasourceAndDelegate?.delegate = self
        let playlistnib = UINib(nibName: "VLCPlaylistCollectionViewCell", bundle:nil)
        collectionView?.register(playlistnib, forCellWithReuseIdentifier: VLCPlaylistCollectionViewCell.cellIdentifier())
        collectionView?.backgroundColor = PresentationTheme.current.colors.background
        collectionView?.alwaysBounceVertical = true
        collectionView?.dataSource = mediaDatasourceAndDelegate
        collectionView?.delegate = mediaDatasourceAndDelegate
        if #available(iOS 11.0, *) {
            collectionView?.dragDelegate = dragAndDropManager
            collectionView?.dropDelegate = dragAndDropManager
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        services.mediaDataSource.updateContents(forSelection: nil)
        services.mediaDataSource.addAllFolders()
        services.mediaDataSource.addRemainingFiles()
        collectionView?.reloadData()
        displayEmptyViewIfNeeded()
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
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            navigationItem.titleView = searchController?.searchBar
            searchController?.hidesNavigationBarDuringPresentation = false
        }
    }

    func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("SORT", comment: ""), style: .plain, target: self, action: #selector(sort))
    }
    
    func displayEmptyViewIfNeeded() {
        collectionView?.backgroundView = collectionView?.numberOfItems(inSection: 0) == 0 ? emptyView : nil
    }

    // MARK: Renderer
    private func setupRendererButton() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rendererButton)
    }

    @objc func sort() {
        delegate?.mediaViewControllerDidSelectSort(self)
    }

    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    // MARK: - MediaDatasourceAndDelegate
    override public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.mediaViewControllerDidSelectMediaObject(self, mediaObject:services.mediaDataSource.object(at: UInt(indexPath.row)))
    }

    // MARK: - Search
    public func updateSearchResults(for searchController: UISearchController) {
        searchDataSource.shouldReloadTable(forSearch: searchController.searchBar.text, searchableFiles: services.mediaDataSource.allObjects())
        collectionView?.reloadData()
    }

    public func didPresentSearchController(_ searchController: UISearchController) {
        collectionView?.dataSource = searchDataSource
    }

    public func didDismissSearchController(_ searchController: UISearchController) {
        collectionView?.dataSource = mediaDatasourceAndDelegate
    }
}
