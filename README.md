# VLC for iOS & tvOS

This is the official mirror repository of VLC for iOS and tvOS application.

_You can find the official repository [here](https://code.videolan.org/videolan/vlc-ios/)._

It's currently written in Objective-C / Swift and uses [VLCKit](https://code.videolan.org/videolan/VLCKit), a libvlc wrapper.

- [Requirements](#requirements)
- [Building](#building)
    - [VLC-iOS](#vlc-ios)
    - [Custom VLCKit](#custom-vlckit)
- [Contribute](#contribute)
- [Communication](#communication)
    - [Forum](#forum)
    - [Issues](#issues)
    - [IRC](#irc)
- [Code of Conduct](#code-of-conduct)
- [License](#license)
- [More](#more)

## Requirements
* Xcode 9.0+
* macOS 10.12+
* Cocoapods 1.4+

## Building

### VLC-iOS

1. Run `pod install`.
2. Open `VLC.xcworkspace`.
3. Hit "Build and Run".

### Custom VLCkit

Mostly for debugging or advanced users, you might want to have a custom local VLCKit build.

1. Clone VLCKit:

    `git clone https://code.videolan.org/videolan/VLCKit.git`


2. Inside the VLCKit folder, run the following command:

    `./buildMobileVLCKit.sh -a ${MYARCH}`

    MYARCH can be `i386` `x86_64` `armv7` `armv7s` or `aarch64`.

    Add `-d` for a debug build (to have valid stack straces and asserts).

    Add `-n` if you want to use you own VLC repository for VLCKit (See [VLCKit README.md](https://code.videolan.org/videolan/VLCKit/blob/master/README.md)).

3. Replace the MobileVLCKit.framework with the one you just build.

    Inside your vlc-ios folder, after a `pod update`, do:

    `cd Pods/MobileVLCKit-unstable/MobileVLCKit-binary`

    `rm -rf MobileVLCKit.framework`

    `ln -s ${VLCKit}/build/MobileVLCKit.framework`

4. Hit "Build and Run".

## Contribute

### Pull request

Pull request are more than welcome! If you do submit one, please make sure to use a descriptive title and description.

### Gitlab issues

You can look through issues we currently have on the [VideoLAN Gitlab](https://code.videolan.org/videolan/vlc-ios/issues).

A [beginner friendly](https://code.videolan.org/videolan/vlc-ios/issues?label_name%5B%5D=Beginner+friendly) tag is available if you don't know where to start.

## Communication

### Forum

If you have any question or if you're not sure it's actually an issue, please visit our [forum](https://forum.videolan.org/).

### Issues

You have encountered an issue and wish to report it to the VLC dev team?

You can create one on our [Gitlab](https://code.videolan.org/videolan/vlc-ios/issues) or on our [bug tracker](https://trac.videolan.org/vlc/).

Before creating an issue or ticket, please double check for duplicates!

### IRC

Want to quickly get in touch with us for a question, or even just to talk?

You will always find someone from the VLC team on IRC, __#videolan__ channel on the freenode network.

For VLC-iOS specific questions, you can find us on __#vlc-ios__.

If you don't have an IRC client, you can always use the [freenode webchat](https://webchat.freenode.net/).

## Code of Conduct

Please read and follow the [VideoLAN CoC](https://wiki.videolan.org/Code_of_Conduct/).

## License

VLC-iOS is under the GPLv2 (or later) and the MPLv2 license.

See [COPYING](./COPYING) for more license info.

## More

For everything else, check our [wiki](https://wiki.videolan.org/) or our [support page](http://www.videolan.org/support/).

We're happy to help!
