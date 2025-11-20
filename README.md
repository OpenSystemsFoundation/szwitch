# Szwitch

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build and Release](https://github.com/OpenSystemsFoundation/szwitch/actions/workflows/release.yml/badge.svg)](https://github.com/OpenSystemsFoundation/szwitch/actions/workflows/release.yml)

A lightweight macOS menu bar app to switch between multiple GitHub accounts seamlessly.

## ✨ Features

- 🎯 **Menu Bar Interface**: Always accessible from your menu bar
- 👥 **Multiple Profiles**: Manage unlimited GitHub accounts
- 🔐 **GitHub CLI Integration**: Secure authentication via `gh` CLI
- ⚙️ **Git Config Switching**: Automatically updates `user.name` and `user.email`
- 🔄 **Seamless Switching**: One-click profile switching with visual feedback
- 📊 **CLI Output View**: Real-time authentication feedback

## Prerequisites

**GitHub CLI (`gh`) must be installed:**

```bash
brew install gh
```

If you don't have Homebrew, install it from [brew.sh](https://brew.sh).

## Installation

### Option 1: Download Release (Recommended)

1. Go to [Releases](https://github.com/OpenSystemsFoundation/szwitch/releases)
2. Download the latest `Szwitch-{version}.dmg`
3. Open the DMG and drag Szwitch to Applications

#### ⚠️ First Launch: Bypassing Gatekeeper

Since Szwitch is not code-signed with an Apple Developer ID certificate, macOS Gatekeeper will block it on first launch. **This is expected behavior.**

**To open Szwitch for the first time:**

**Method 1: Right-Click → Open (Recommended)**
1. Go to Applications folder
2. **Right-click** (or Control+Click) on Szwitch.app
3. Select **"Open"** from the menu
4. Click **"Open"** in the security dialog
5. After the first time, you can open it normally

**Method 2: System Settings**
1. Try to open Szwitch normally (it will be blocked)
2. Go to **System Settings** → **Privacy & Security**
3. Scroll down to find "Szwitch was blocked"
4. Click **"Open Anyway"**
5. Click **"Open"** in the confirmation dialog

**Method 3: Terminal Command**
```bash
xattr -cr /Applications/Szwitch.app
open /Applications/Szwitch.app
```

> **Note**: The app is open source and built from this repository. You can review the code or build it yourself from source for additional confidence.

### Option 2: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/OpenSystemsFoundation/szwitch.git
   cd szwitch
   ```

2. Generate icons and build:
   ```bash
   swift scripts/create_icon.swift
   ./scripts/build_app.sh
   ```

3. Run:
   ```bash
   open Szwitch.app
   ```

## Usage

1. Click the menu bar icon (person circle).
2. Click **+** to add a profile.
3. When prompted, authenticate via `gh auth login` in your terminal.
4. Enter your Name and Email (for git config).
5. Click **Save**.
6. Click any profile in the list to switch to it.

The app will automatically switch your git configuration and GitHub CLI authentication when you select a profile.
