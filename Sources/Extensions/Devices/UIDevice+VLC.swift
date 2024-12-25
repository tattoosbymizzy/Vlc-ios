/*****************************************************************************
 * UIDevice+VLC.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2021 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Edgar Fouillet <vlc # edgar.fouillet.eu>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

@objc extension UIDevice {

    @objc(VLCHasExternalDisplay)
    var hasExternalDisplay: Bool {
        if UIScreen.screens.count <= 1 {
            return false
        }

        if #available(iOS 13.0, tvOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if scene.session.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" {
                    return false
                }
            }
        }
        return true
    }

    @objc(VLCDeviceHasSafeArea)
    static var hasSafeArea: Bool {
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        return keyWindow?.safeAreaInsets.bottom ?? 0 > 0
    }

    static var hasNotch: Bool {
        return hasSafeArea
    }
}
