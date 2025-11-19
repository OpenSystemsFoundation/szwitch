# Szwitch

A lightweight macOS menu bar app to switch between multiple GitHub accounts seamlessly.

## Features
- **Menu Bar Interface**: Always accessible.
- **Multiple Profiles**: Add as many GitHub accounts as you need.
- **OAuth Support**: Secure login via GitHub Device Flow.
- **Git Config Switching**: Automatically updates `user.name` and `user.email`.
- **Keychain Integration**: Updates your system Keychain so `git push` just works.

## Installation

1. **Build the App**:
   ```bash
   ./scripts/build_app.sh
   ```
2. **Run**:
   Open `Szwitch.app` in the current directory.

## Setup (Important!)

To use the OAuth login, you need a **Client ID**. Since this is a custom open-source tool, you must register your own "App" on GitHub once:

1. Go to [GitHub Developer Settings > OAuth Apps](https://github.com/settings/developers).
2. Click **New OAuth App**.
3. Fill in:
   - **Application Name**: Szwitch (or anything)
   - **Homepage URL**: `http://localhost`
   - **Authorization callback URL**: `http://localhost`
4. Click **Register application**.
5. Copy the **Client ID** (e.g., `Iv1.8a...`).
6. Open **Szwitch**, click "Add Account", and paste the Client ID.

## Usage

1. Click the menu bar icon (person circle).
2. Click **+** to add a profile.
3. Login with GitHub.
4. Enter your Name and Email (for git config).
5. Click **Save**.
6. Click any profile in the list to switch to it.
