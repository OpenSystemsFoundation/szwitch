# Szwitch

[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

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

1. **Build the App**:
   ```bash
   ./scripts/build_app.sh
   ```
2. **Run**:
   Open `Szwitch.app` in the current directory.

## Usage

1. Click the menu bar icon (person circle).
2. Click **+** to add a profile.
3. When prompted, authenticate via `gh auth login` in your terminal.
4. Enter your Name and Email (for git config).
5. Click **Save**.
6. Click any profile in the list to switch to it.

The app will automatically switch your git configuration and GitHub CLI authentication when you select a profile.
