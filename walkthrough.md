# Verification: Szwitch

The app is built and ready. Follow these steps to verify it works.

## 1. Build the App
Ensure the app is built with the latest changes:
```bash
./scripts/build_app.sh
```

## 2. Launch
Open the app from Finder or terminal:
```bash
open Szwitch.app
```
*You should see a "person" icon appear in your menu bar.*

## 3. Configure OAuth (One-time)
1. Click the menu bar icon.
2. Select **Settings...** from the menu.
3. In the Settings window, go to the **General** tab.
4. Enter your **Client ID** (from GitHub Developer Settings).

## 4. Add Profiles
1. In the Settings window, go to the **Profiles** tab.
2. Click **Add Account**.
3. Click **Login with GitHub**.
4. Copy the code and authorize in the browser.
5. Once authenticated, enter a **Name** and **Email**.
6. Click **Save**.

## 5. Verify Switching
1. Click the menu bar icon.
2. You will see your profiles listed.
3. Click a profile to switch to it.
   - A checkmark indicates the active profile.
4. Verify in terminal:
   ```bash
   git config --global user.email
   ```
