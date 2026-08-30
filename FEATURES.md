# Features of Badgeify & Implementation Status

Here is the tracking roadmap for the features of **smartbadges** and what has been implemented so far.

---

## 1. Core Feature Status

### 🔔 Notification Tracking & Badging
* [x] **System & Third-Party App Integration:** Monitors notification counts from various macOS apps (e.g., Mail, Messages, Slack, WhatsApp, App Store).
* [x] **Dock-less Monitoring:** Allows users to track notifications via the menu bar.
* [x] **Accessibility API Dependency:** Reads badge values/updates from the macOS Accessibility API (`AXStatusLabel`).

### 🎨 Customization & Appearance
* [x] **Dynamic App Icons in Menu Bar:** Displays the actual resized 16x16 icon of the application next to its count.
* [x] **Selection Configuration:** Checkbox list allows choosing which apps get their own menu bar icons.
* [x] **Main Control Icon:** Always present clean, monochrome menu bar control icon (`app.badge` SF Symbol) for configurations and fallback.
* [ ] **Custom Notification Colors:** Customize notification badge highlight colors.

### ⚡ Organization & Productivity
* [x] **Click-to-Focus App Launching:** Clicking an app's icon in the menu bar launches or focuses the app directly.
* [x] **Consolidated Badges:** Any apps not selected for individual icons are aggregated and displayed as a sum on the main SmartBadges icon.
* [ ] **App Groups:** Combine multiple related applications under a single custom menu bar icon.

### ⚙️ Automation & CLI
* [ ] **CLI Integration:** Programmatically query status, control settings, or trigger updates via a CLI tool.
