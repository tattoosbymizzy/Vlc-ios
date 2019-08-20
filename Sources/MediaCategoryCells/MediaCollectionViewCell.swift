/*****************************************************************************
 * MediaCollectionViewCell.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Carola Nitz <nitz.carola # googlemail.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

class MediaCollectionViewCell: BaseCollectionViewCell {

    @IBOutlet private weak var thumbnailView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var newLabel: UILabel!
    @IBOutlet private weak var thumbnailWidth: NSLayoutConstraint!

    override var media: VLCMLObject? {
        didSet {
            if let albumTrack = media as? VLCMLMedia, albumTrack.subtype() == .albumTrack {
                update(audiotrack:albumTrack)
            } else if let album = media as? VLCMLAlbum {
                update(album:album)
            } else if let artist = media as? VLCMLArtist {
                update(artist:artist)
            } else if let movie = media as? VLCMLMedia, movie.subtype() == .unknown {
                update(movie:movie)
            } else if let playlist = media as? VLCMLPlaylist {
                update(playlist: playlist)
            } else if let genre = media as? VLCMLGenre {
                update(genre: genre)
            } else {
                fatalError("needs to be of Type VLCMLMedia or VLCMLAlbum")
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 11.0, *) {
            thumbnailView.accessibilityIgnoresInvertColors = true
        }
        newLabel.text = NSLocalizedString("NEW", comment: "")
        newLabel.textColor = PresentationTheme.current.colors.orangeUI
        let isIpad = UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad
        thumbnailWidth.constant = isIpad ? 72 : 56
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: .VLCThemeDidChangeNotification, object: nil)
        themeDidChange()
    }

    @objc fileprivate func themeDidChange() {
        backgroundColor = PresentationTheme.current.colors.background
        titleLabel?.textColor = PresentationTheme.current.colors.cellTextColor
        descriptionLabel?.textColor = PresentationTheme.current.colors.cellDetailTextColor
    }

    func update(audiotrack: VLCMLMedia) {
        var title = audiotrack.title
        if  UserDefaults.standard.bool(forKey: kVLCOptimizeItemNamesForDisplay) == true {
            title = (title as NSString).deletingPathExtension
        }
        titleLabel.text = title
        accessibilityLabel = audiotrack.accessibilityText(editing: false)
        descriptionLabel.text = audiotrack.albumTrackArtistName()
        newLabel.isHidden = !audiotrack.isNew
        thumbnailView.image = audiotrack.thumbnailImage()
    }

    func update(album: VLCMLAlbum) {
        titleLabel.text = album.albumName()
        accessibilityLabel = album.accessibilityText(editing: false)
        descriptionLabel.text = album.albumArtistName()
        thumbnailView.image = album.thumbnail()
    }

    func update(artist: VLCMLArtist) {
        thumbnailView.layer.masksToBounds = true
        thumbnailView.layer.cornerRadius = thumbnailView.frame.size.width / 2.0
        titleLabel.text = artist.artistName()
        accessibilityLabel = artist.accessibilityText()
        descriptionLabel.text = artist.numberOfTracksString()
        thumbnailView.image = artist.thumbnail()
    }

    func update(movie: VLCMLMedia) {
        var title = movie.title
        if  UserDefaults.standard.bool(forKey: kVLCOptimizeItemNamesForDisplay) == true {
            title = (title as NSString).deletingPathExtension
        }
        titleLabel.text = title
        accessibilityLabel = movie.accessibilityText(editing: false)
        descriptionLabel.text = movie.mediaDuration()
        thumbnailView.image = movie.thumbnailImage()
        newLabel.isHidden = !movie.isNew
    }

    func update(playlist: VLCMLPlaylist) {
        newLabel.isHidden = true
        titleLabel.text = playlist.name
        accessibilityLabel = playlist.accessibilityText()
        descriptionLabel.text = playlist.numberOfTracksString()
        thumbnailView.image = playlist.thumbnail()
    }

    func update(genre: VLCMLGenre) {
        newLabel.isHidden = true
        titleLabel.text = genre.name
        accessibilityLabel = genre.accessibilityText()

        thumbnailView.image = genre.thumbnail()
        descriptionLabel.text = genre.numberOfTracksString()
    }

    override class func cellSizeForWidth(_ width: CGFloat) -> CGSize {
        let numberOfCells: CGFloat
        if width <= DeviceWidth.iPhonePortrait.rawValue {
            numberOfCells = 1
        } else if width <= DeviceWidth.iPadLandscape.rawValue {
            numberOfCells = 2
        } else {
            numberOfCells = 3
        }

        // We have the number of cells and we always have numberofCells + 1 interItemPadding spaces.
        //
        // edgePadding-interItemPadding-[Cell]-interItemPadding-[Cell]-interItemPadding-edgePadding
        //

        let overallWidth = width - (2 * edgePadding)
        let overallCellWidthWithoutPadding = overallWidth - (numberOfCells + 1) * interItemPadding
        let cellWidth = floor(overallCellWidthWithoutPadding / numberOfCells)

        let isIpad = UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad
        return CGSize(width: cellWidth, height: isIpad ? 94 : 60)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        accessibilityLabel = ""
        descriptionLabel.text = ""
        thumbnailView.image = nil
        newLabel.isHidden = true
    }
}
