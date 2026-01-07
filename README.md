# Click2Hide (Stable Fork)

![Click2Hide Logo](Click2Hide/Assets.xcassets/AppIcon.appiconset/128-mac.png)

## Overview

**Click2Hide (Stable)** is a fork of the original [Click2Hide](https://github.com/victorwon/click2hide) by Victor Won. This version has been specifically refactored and optimized for **macOS Sequoia** to provide a "drama-free" experience.

It solves the common "app swapping" and "refusal to open" bugs found in the original version when used with modern macOS Accessibility settings.

## Key Improvements in this Fork

*   **Minimum Intervention Strategy**: Click2Hide now only intercepts clicks to **hide** an active app. It lets the native macOS Dock handle all **show/unminimize** actions, ensuring 100% reliability.
*   **Universal Matcher**: Automatically identifies Safari, Terminal, and third-party apps by checking localized names, bundle IDs, and executable paths simultaneously.
*   **WhatsApp Fix**: Full support for the latest WhatsApp Desktop client (`net.whatsapp.WhatsApp`).
*   **Sequoia Optimized**: Faster response times and improved permission polling.

## Installation

1. Clone this repository or download the source.
2. Build using Xcode: `xcodebuild -project Click2Hide.xcodeproj -scheme Click2Hide -configuration Release build`.
3. Move the resulting `Click2Hide.app` to your Applications folder.
4. **Grant Permissions**: Open **System Settings > Privacy & Security > Accessibility** and add Click2Hide.

## Usage

*   **Hide Applications**: Click the icon of the application that is currently frontmost.
*   **Show Applications**: Click any background or minimized icon. The native Dock will bring it forward.

## Credits & License

This project is a stable fork of the original work by **Victor Won**. 
Original Repository: [github.com/victorwon/click2hide](https://github.com/victorwon/click2hide)

Licensed under the **MIT License**. See `LICENSE` for details.
