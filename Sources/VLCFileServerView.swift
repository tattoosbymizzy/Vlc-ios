/*****************************************************************************
 * VLCFileServerView.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2018 VideoLAN. All rights reserved.
 * $Id$
 *
 * Author: Carola Nitz <caro # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

@objc protocol VLCFileServerViewDelegate: NSObjectProtocol {

    func connectToServer()
}

class VLCFileServerView: UIView {

    @objc weak var delegate: VLCFileServerViewDelegate?
    lazy var connectButton: UIButton = {
        let connectButton = UIButton(type: .system)
        connectButton.setTitle(NSLocalizedString("BUTTON_CONNECT", comment: ""), for: .normal)
        connectButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        connectButton.setTitleColor(PresentationTheme.current.colors.orangeUI, for: .normal)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.addTarget(self, action: #selector(connectButtonDidPress), for: .touchUpInside)
        addSubview(connectButton)
        return connectButton
    }()

    lazy var textLabel: UILabel = {
        let textLabel = UILabel(frame: .zero)
        textLabel.text = NSLocalizedString("FILE_SERVER", comment: "")
        textLabel.font = PresentationTheme.current.font.tableHeaderFont
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)
        return textLabel
    }()

    lazy var separator: UIView = {
        let separator = UIView(frame: .zero)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        return separator
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTheme), name: .VLCThemeDidChangeNotification, object: nil)
        setupUI()
        updateTheme()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func updateTheme() {
        backgroundColor = PresentationTheme.current.colors.background
        separator.backgroundColor = PresentationTheme.current.colors.separatorColor
        textLabel.textColor = PresentationTheme.current.colors.cellTextColor
    }

    func setupUI() {
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.topAnchor.constraint(equalTo: topAnchor),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: connectButton.leadingAnchor),
            connectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            textLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 15),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            connectButton.firstBaselineAnchor.constraint(equalTo: textLabel.firstBaselineAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
            ])
    }

    @objc func connectButtonDidPress() {
        delegate?.connectToServer()
    }
}
