/*****************************************************************************
 * PresentationTheme.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Carola Nitz <caro # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

extension Notification.Name {
    static let VLCThemeDidChangeNotification = Notification.Name("themeDidChangeNotfication")
}

@objcMembers class ColorPalette: NSObject {

    let isDark: Bool
    let name: String
    let statusBarStyle: UIStatusBarStyle
    let navigationbarColor: UIColor
    let navigationbarTextColor: UIColor
    let background: UIColor
    let cellBackgroundA: UIColor
    let cellBackgroundB: UIColor
    let cellDetailTextColor: UIColor
    let cellTextColor: UIColor
    let lightTextColor: UIColor
    let sectionHeaderTextColor: UIColor
    let separatorColor: UIColor
    let mediaCategorySeparatorColor: UIColor
    let tabBarColor: UIColor
    let orangeUI: UIColor
    let toolBarStyle: UIBarStyle

    init(isDark: Bool,
                name: String,
                statusBarStyle: UIStatusBarStyle,
                navigationbarColor: UIColor,
                navigationbarTextColor: UIColor,
                background: UIColor,
                cellBackgroundA: UIColor,
                cellBackgroundB: UIColor,
                cellDetailTextColor: UIColor,
                cellTextColor: UIColor,
                lightTextColor: UIColor,
                sectionHeaderTextColor: UIColor,
                separatorColor: UIColor,
                mediaCategorySeparatorColor: UIColor,
                tabBarColor: UIColor,
                orangeUI: UIColor,
                toolBarStyle: UIBarStyle) {
        self.isDark = isDark
        self.name = name
        self.statusBarStyle = statusBarStyle
        self.navigationbarColor = navigationbarColor
        self.navigationbarTextColor = navigationbarTextColor
        self.background = background
        self.cellBackgroundA = cellBackgroundA
        self.cellBackgroundB = cellBackgroundB
        self.cellDetailTextColor = cellDetailTextColor
        self.cellTextColor = cellTextColor
        self.lightTextColor = lightTextColor
        self.sectionHeaderTextColor = sectionHeaderTextColor
        self.separatorColor = separatorColor
        self.mediaCategorySeparatorColor = mediaCategorySeparatorColor
        self.tabBarColor = tabBarColor
        self.orangeUI = orangeUI
        self.toolBarStyle = toolBarStyle
    }
}

@objcMembers class Typography: NSObject {
    
    let tableHeaderFont: UIFont
    
    init(tableHeaderFont: UIFont) {
        self.tableHeaderFont = tableHeaderFont
    }
}

@objcMembers class PresentationTheme: NSObject {

    static let brightTheme = PresentationTheme(colors: brightPalette)
    static let darkTheme = PresentationTheme(colors: darkPalette)

    static var current: PresentationTheme = {
        if let appTheme = UserDefaults.standard.value(forKey: kVLCSettingAppTheme) {
            return appTheme as! Int32 == kVLCSettingAppThemeDark ? PresentationTheme.darkTheme : PresentationTheme.brightTheme
        } else {
            return PresentationTheme.brightTheme
        }
    }() {
        didSet {
            AppearanceManager.setupAppearance(theme: self.current)
            NotificationCenter.default.post(name: .VLCThemeDidChangeNotification, object: self)
        }
    }

    init(colors: ColorPalette) {
        self.colors = colors
        super.init()
    }

    static func settingsDidUpdate() {
        if let themeSettings = UserDefaults.standard.value(forKey: kVLCSettingAppTheme) {
            let mode = themeSettings as! Int32
            if mode == kVLCSettingAppThemeBright {
                PresentationTheme.current = PresentationTheme.brightTheme
            } else if mode == kVLCSettingAppThemeDark {
                PresentationTheme.current = PresentationTheme.darkTheme
            } else {
                if #available(iOS 13.0, *) {
                    let isSystemDarkTheme = UIScreen.main.traitCollection.userInterfaceStyle == .dark
                    PresentationTheme.current = isSystemDarkTheme ? PresentationTheme.darkTheme : PresentationTheme.brightTheme
                }
            }
        }
    }

    let colors: ColorPalette
    let font = defaultFont
}

@objc extension UIColor {

    convenience init(_ rgbValue: UInt32, _ alpha: CGFloat = 1.0) {
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0xFF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func toHex(alpha: Bool = false) -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            assertionFailure()
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count == 4 {
            a = Float(components[3])
        }

        if alpha {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }

    var toHex: String? {
        return toHex()
    }
}

let brightPalette = ColorPalette(isDark: false,
                                 name: "Default",
                                 statusBarStyle: .autoDarkContent,
                                 navigationbarColor: UIColor(0xFFFFFF),
                                 navigationbarTextColor: UIColor(0x000000),
                                 background: UIColor(0xFFFFFF),
                                 cellBackgroundA: UIColor(0xFFFFFF),
                                 cellBackgroundB: UIColor(0xE5E5E3),
                                 cellDetailTextColor: UIColor(0x84929C),
                                 cellTextColor: UIColor(0x000000),
                                 lightTextColor: UIColor(0x888888),
                                 sectionHeaderTextColor: UIColor(0x25292C),
                                 separatorColor: UIColor(0xF0F2F7),
                                 mediaCategorySeparatorColor: UIColor(0xECF2F6),
                                 tabBarColor: UIColor(0xFFFFFF),
                                 orangeUI: UIColor(0xFF8800),
                                 toolBarStyle: UIBarStyle.default)

let darkPalette = ColorPalette(isDark: true,
                               name: "Dark",
                               statusBarStyle: .lightContent,
                               navigationbarColor: UIColor(0x1B1E21),
                               navigationbarTextColor: UIColor(0xFFFFFF),
                               background: UIColor(0x1B1E21),
                               cellBackgroundA: UIColor(0x1B1E21),
                               cellBackgroundB: UIColor(0x494B4D),
                               cellDetailTextColor: UIColor(0x84929C),
                               cellTextColor: UIColor(0xFFFFFF),
                               lightTextColor: UIColor(0xB8B8B8),
                               sectionHeaderTextColor: UIColor(0x828282),
                               separatorColor: UIColor(0x25292C),
                               mediaCategorySeparatorColor: UIColor(0x25292C),
                               tabBarColor: UIColor(0x25292C),
                               orangeUI: UIColor(0xFF8800),
                               toolBarStyle: UIBarStyle.black)

let defaultFont = Typography(tableHeaderFont: UIFont.systemFont(ofSize: 24, weight: .semibold))

// MARK: - UIStatusBarStyle - autoDarkContent

extension UIStatusBarStyle {
    static var autoDarkContent: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        } else {
            return .default
        }
    }
}
