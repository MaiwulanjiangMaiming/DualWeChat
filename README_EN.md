<div align="center">

# DualWeChat

**Run two WeChat on macOS with one click**

Duplicate and modify Bundle Identifier for truly independent dual instances.

[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[中文](README.md)

</div>

---

## Quick Start

```bash
git clone https://github.com/MaiwulanjiangMaiming/DualWeChat.git
cd DualWeChat
chmod +x setup.sh
./setup.sh
```

During installation, you will be asked to choose an icon color scheme:

| # | Name | Style |
|---|------|-------|
| 1 | Metal | Metallic dark |
| 2 | Aurora | Cold blue aurora |
| 3 | Neon | Purple-pink neon |
| 4 | Lava | Orange-gold flame |
| 5 | Matrix | Hacker terminal green |

After installation, **DualWeChat** will appear in Launchpad. Run it alongside the original **WeChat** and log in with a different account.

---

## Why This Project

WeChat on macOS checks if an instance is already running. If you double-click the WeChat icon twice, the second click only activates the existing window instead of launching a second instance.

This project duplicates the WeChat app and modifies its Bundle Identifier, making the system treat them as two completely different apps, thus bypassing the single-instance check.

### Comparison

| Method | Principle | Result |
|--------|-----------|--------|
| `nohup WeChat &` | Background launch | ❌ Detected by newer WeChat |
| `open -n WeChat.app` | Force new instance | ❌ Same, blocked |
| **Modify Bundle ID** | Duplicate & change ID | ✅ Bypasses detection |

---

## Manual Install (Optional)

If you prefer not to use the script:

```bash
# Copy WeChat
sudo cp -R /Applications/WeChat.app /Applications/DualWeChat.app

# Change Bundle ID
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier com.tencent.xinWeChat.dual" \
    /Applications/DualWeChat.app/Contents/Info.plist

# Rename
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleDisplayName DualWeChat" \
    /Applications/DualWeChat.app/Contents/Info.plist
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleName DualWeChat" \
    /Applications/DualWeChat.app/Contents/Info.plist

# Re-sign
sudo codesign --force --deep --sign - /Applications/DualWeChat.app

# Refresh Dock
sudo touch /Applications/DualWeChat.app && sudo killall Dock
```

---

## Custom Icon

The install script includes 5 color themes. You can also specify one manually:

```bash
pip3 install Pillow numpy
python3 generate_icon.py /Applications/DualWeChat.app/Contents/Resources/AppIcon.icns aurora
sudo codesign --force --deep --sign - /Applications/DualWeChat.app
```

Available schemes: `metal`, `aurora`, `neon`, `lava`, `matrix`

You can also directly replace with any `.icns` file.

---

## Usage

- **WeChat** — Log in to account 1
- **DualWeChat** — Log in to account 2

Notifications are independent between the two apps. Because the icons are different, you can tell them apart at a glance. Notification settings can be configured separately in System Settings.

> **After WeChat updates**: DualWeChat won't auto-update. Run the following command to check and update:
> ```bash
> ./update.sh
> ```
> The script compares version numbers between the two apps and calls `setup.sh` when a new version is detected.

---

## Uninstall

```bash
sudo rm -rf /Applications/DualWeChat.app
```

---

## Credits

Inspired by [CLOUDUH/dual-wechat](https://github.com/CLOUDUH/dual-wechat). This project adopts a more reliable Bundle ID modification approach to bypass newer WeChat's single-instance detection.

## License

[MIT](LICENSE)
