/*****************************************************************************
 * VLCPlaylistViewController.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Carola Nitz <caro # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

class VLCPlaylistViewController: VLCMediaViewController {
    override init(services: Services) {
        super.init(services: services)
        setupUI()
    }

    private func setupUI() {
        title = NSLocalizedString("PLAYLISTS", comment: "")
        tabBarItem = UITabBarItem(
            title: NSLocalizedString("PLAYLISTS", comment: ""),
            image: UIImage(named: "TVShowsIcon"),
            selectedImage: UIImage(named: "TVShowsIcon"))
        tabBarItem.accessibilityIdentifier = VLCAccessibilityIdentifier.playlist
    }

    override func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
        return [
            VLCPlaylistCategoryViewController(services)
        ]
    }
}
