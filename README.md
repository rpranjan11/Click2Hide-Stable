# Click2Hide (Stable Fork)

![Click2Hide Logo](Click2Hide/Assets.xcassets/AppIcon.appiconset/128-mac.png)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/rpranjan11/Click2Hide-Stable?color=blue&label=release)](https://github.com/rpranjan11/Click2Hide-Stable/releases)

## Overview

**Click2Hide (Stable)** is a high-performance fork of Click2Hide, specifically optimized for **macOS Sequoia**. It provides a reliable way to hide and un-minimize applications by clicking their icons directly in the Dock.

This version implements a **"Minimum Intervention"** strategy—intercepting clicks only to minimize active windows while allowing the macOS Dock to handle all application activation and recovery. This ensures 100% stability and compatibility with native macOS features like the **Genie/Scale effect**.

## Key Features

*   **Native Animations**: Full support for Genie and Scale effects during minimization.
*   **Universal Matcher**: Seamlessly works with all apps (Safari, Terminal, Chrome, WhatsApp, etc.) by matching bundle IDs and localized titles.
*   **Sequoia Optimized**: Fixed the common "app swapping" and "refusal to open" bugs found in the original open-source version.
*   **Lightweight**: Minimal CPU/Memory footprint.

## Installation & Security

To install Click2Hide on your Mac:

1.  **Download**: Get the latest version from the **[Releases](https://github.com/rpranjan11/Click2Hide-Stable/releases)** page.
2.  **Move to Applications**: Unzip and drag `Click2Hide.app` into your `/Applications` folder.
3.  **Bypass Gatekeeper**: 
    -   Because this is an independent open-source build, macOS may say "Developer cannot be verified." 
    -   To open: **Right-Click** the app in Finder and choose **Open**, then click **Open** again in the dialog. Or go to **System Settings > Privacy & Security** and click **Open Anyway**.
4.  **Grant Permissions**: 
    -   Go to **System Settings > Privacy & Security > Accessibility**.
    -   Enable **Click2Hide**. If it's already there but not working, remove it with the `-` button and add it again with `+`.

## Usage

-   **Hide Active App**: Click the Dock icon of the app you are currently using. It will minimize with your selected macOS animation.
-   **Show/Recovery**: Click any other icon. Click2Hide steps aside and lets the macOS Dock handle the activation perfectly.

---
**Developed by Ranjan Ram Pratap**  
Explore more projects at [theranjana.com](https://theranjana.com)

---
*Original Base by Victor Won. Licensed under the MIT License.*
