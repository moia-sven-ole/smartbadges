# SmartBadges 🚀

Transform your Mac's menu bar into a dynamic notification and app launching hub.

SmartBadges monitors notification counts from apps in your macOS Dock using Accessibility APIs and shows them directly in your menu bar.

---

## 🛠️ Features Implemented

* **🔔 Notification Tracking:** Reads notification badge counts (`AXStatusLabel`) from the Dock via the macOS Accessibility API.
* **🎨 Dynamic Multi-Icons (Option A):** Shows individual application icons with badge counts side-by-side in the menu bar for selected apps.
* **⚡ Click-to-Focus:** Click directly on any app's status icon to instantly launch or focus that application.
* **⚙️ Selective Monitoring:** A checkbox list in the main menu lets you choose which apps get individual icons.
* **📦 Consolidated Badge Count:** Apps that are not checked have their counts summed up and displayed on the main SmartBadges icon.
* **🔑 Stable Local Code Signing:** The build script automatically generates a local developer certificate and signs the bundle so you don't lose accessibility permissions when rebuilding.

---

## 🚀 How to Build and Run

1. Open your terminal in the project directory.
2. Compile and package the app bundle:
   ```bash
   ./build.sh
   ```
3. Launch the application:
   ```bash
   open SmartBadges.app
   ```

### ⚠️ Permissions Setup
On the first launch:
1. macOS will request Accessibility permission. Click **Open System Settings** (or manually go to **System Settings > Privacy & Security > Accessibility**).
2. Toggle the switch next to **SmartBadges** to enable it.
3. If it does not detect immediately, click **Check Accessibility Permission** in the SmartBadges dropdown.
