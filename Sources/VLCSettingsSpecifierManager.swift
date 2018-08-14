/*****************************************************************************
 * VLCSettingsSpecifierManager.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright © 2018 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Mike JS. Choi <mkchoi212 # icloud.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import UIKit

class VLCSettingsSpecifierManager: NSObject {
    
    @objc var specifier: IASKSpecifier?
    var settingsReader: IASKSettingsReader
    var settingsStore: IASKSettingsStore
    
    var items: NSArray {
        guard let items = specifier?.multipleValues() as NSArray? else {
            fatalError("VLCSettingsSpecifierManager: No rows provided for \(specifier?.key() ?? "null specifier")")
        }
        return items
    }
    
    @objc var selectedIndex: IndexPath {
        let index: Int
        if let selectedItem = settingsStore.object(forKey: specifier?.key()) {
            index = items.index(of: selectedItem)
        } else if let specifier = specifier {
            index = items.index(of: specifier.defaultValue())
        } else {
            fatalError("VLCSettingsSpecifierManager: No specifier provided")
        }
        return IndexPath(row: index, section: 0)
    }
    
    @objc init(settingsReader: IASKSettingsReader, settingsStore: IASKSettingsStore) {
        self.settingsReader = settingsReader
        self.settingsStore = settingsStore
        super.init()
    }
}

// MARK: VLCActionSheetDelegate

extension VLCSettingsSpecifierManager: VLCActionSheetDelegate {
    
    func headerViewTitle() -> String? {
        return specifier?.title()
    }
    
    func itemAtIndexPath(_ indexPath: IndexPath) -> Any? {
        return items[indexPath.row]
    }
    
    func actionSheet(collectionView: UICollectionView, didSelectItem item: Any, At indexPath: IndexPath) {
        settingsStore.setObject(item, forKey: specifier?.key())
        settingsStore.synchronize()
    }
}

// MARK: VLCActionSheetDataSource

extension VLCSettingsSpecifierManager: VLCActionSheetDataSource {
    
    func numberOfRows() -> Int {
        return items.count
    }
    
    func actionSheet(collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VLCSettingsSheetCell.identifier, for: indexPath) as? VLCSettingsSheetCell else {
            return UICollectionViewCell()
        }
        
        if let titles = specifier?.multipleTitles(), indexPath.row < titles.count {
            cell.name.text = settingsReader.title(forStringId: titles[indexPath.row] as? String)
        }

        return cell
    }
}
