<div align="center">

# DualWeChat

**macOS 微信双开 · 一键安装 / Run two WeChat on macOS with one click**

通过复制应用并修改 Bundle Identifier，实现两个微信独立运行 / Duplicate and modify Bundle Identifier for truly independent dual instances

[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## ✨ 特性 / Features

| | |
|---|---|
| 🚀 **一键安装 / One-click install** | 运行一个脚本，自动完成所有配置 / Single script handles everything |
| 🔑 **真正独立 / Truly independent** | 不同 Bundle ID，两个微信互不干扰 / Different Bundle IDs, no interference |
| 🎨 **金属图标 / Metallic icon** | 自动生成金属质感黑色图标，一眼区分 / Auto-generated dark metallic icon |
| 🧹 **无残留 / No residue** | 不需要保持终端窗口打开 / No terminal window needed |
| ⚙️ **可自定义 / Customizable** | 图标、名称均可自由修改 / Freely modify icon and name |

## 🔧 原理 / How It Works

> **核心思路：复制 `WeChat.app` 并修改其 `CFBundleIdentifier`。**
>
> **Core idea: Duplicate `WeChat.app` and modify its `CFBundleIdentifier`.**

macOS 通过 `CFBundleIdentifier` 区分不同应用。新版微信会检测同 Bundle ID 的已有实例，拒绝启动第二个。

macOS uses `CFBundleIdentifier` to identify apps. Newer WeChat versions detect existing instances with the same ID and refuse to launch a second one.

| 步骤 Step | 说明 Description |
|-----------|-----------------|
| 1. 复制 `WeChat.app` → `DualWeChat.app` | 创建独立的应用副本 / Create an independent app copy |
| 2. 修改 `CFBundleIdentifier` | `com.tencent.xinWeChat` → `com.tencent.xinWeChat.dual` |
| 3. 修改应用名称 / Rename | `WeChat` → `DualWeChat` |
| 4. 替换图标 / Replace icon | 生成金属黑质感图标（可选）/ Generate metallic dark icon (optional) |
| 5. 重新签名 / Re-sign | `codesign --force --deep --sign -` |

完成后两个应用在系统层面完全独立，可以同时登录不同账号。

After setup, the two apps are completely independent at the system level and can run side by side with different accounts.

### 与其他方案的对比 / Comparison

| 方案 Method | 原理 Principle | 问题 Issue |
|------------|---------------|-----------|
| `nohup WeChat &` | 后台启动主程序 / Background launch | ⚠️ 新版微信检测已有实例，直接激活旧窗口 / New WeChat detects existing instance |
| `open -n WeChat.app` | 强制打开新实例 / Force new instance | ⚠️ 同上 / Same as above |
| **本方案 / This method** | 复制应用并改 Bundle ID / Duplicate & change ID | ✅ 完美绕过单实例检测 / Bypasses single-instance check |

## 🚀 安装 / Installation

### 前置要求 / Prerequisites

- macOS 12.0+
- 已安装微信 / WeChat installed ([App Store](https://apps.apple.com/app/wechat/id836500024) or [Official](https://mac.weixin.qq.com/))
- Python 3 + Pillow + numpy（可选，用于生成自定义图标 / optional, for custom icon）

### 一键安装 / Quick Install

```bash
git clone https://github.com/MaiwulanjiangMaiming/DualWeChat.git
cd DualWeChat
chmod +x setup.sh
./setup.sh
```

安装过程中可能需要输入密码（用于 `sudo` 复制和签名）。
You may be prompted for your password (for `sudo` copy and signing).

### 手动安装 / Manual Install

```bash
# 1. 复制微信 / Copy WeChat
sudo cp -R /Applications/WeChat.app /Applications/DualWeChat.app

# 2. 修改 Bundle ID / Change Bundle ID
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier com.tencent.xinWeChat.dual" \
    /Applications/DualWeChat.app/Contents/Info.plist

# 3. 修改显示名称 / Change display name
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleDisplayName DualWeChat" \
    /Applications/DualWeChat.app/Contents/Info.plist
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleName DualWeChat" \
    /Applications/DualWeChat.app/Contents/Info.plist

# 4. 修改 URL Scheme（可选 / optional）
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleURLTypes:0:CFBundleURLName com.tencent.xinWeChat.dual" \
    /Applications/DualWeChat.app/Contents/Info.plist

# 5. 重新签名 / Re-sign
sudo codesign --force --deep --sign - /Applications/DualWeChat.app

# 6. 刷新 Dock / Refresh Dock
touch /Applications/DualWeChat.app && killall Dock
```

### 自定义图标 / Custom Icon

```bash
pip3 install Pillow numpy
python3 generate_icon.py /Applications/DualWeChat.app/Contents/Resources/AppIcon.icns
sudo codesign --force --deep --sign - /Applications/DualWeChat.app
```

脚本从原版微信图标生成金属质感黑色版本。你也可以手动替换任何 `.icns` 图标文件。

The script generates a metallic dark version from the original WeChat icon. You can also manually replace with any `.icns` file.

## 📱 使用 / Usage

| 应用 App | 用途 Purpose |
|---------|-------------|
| **WeChat** | 登录第一个账号 / Log in to account 1 |
| **DualWeChat** | 登录第二个账号 / Log in to account 2 |

将两个都拖到 Dock 栏，即可随时切换。Drag both to the Dock for easy switching.

## ⚠️ 已知问题 / Known Issues

- 点击微信 A 的通知横幅，可能跳转到微信 B 窗口（微信自身行为 / WeChat's own behavior）
- 电脑休眠后重新唤醒，可能需要重新登录 / May need to re-login after sleep
- 重新登录时可能必须使用扫码方式 / May require QR code login
- 微信更新后需重新运行 `setup.sh` / Re-run `setup.sh` after WeChat updates

## 🗑️ 卸载 / Uninstall

```bash
sudo rm -rf /Applications/DualWeChat.app
killall Dock
```

## 🙏 致谢 / Credits

灵感来源于 [CLOUDUH/dual-wechat](https://github.com/CLOUDUH/dual-wechat)，该方案使用 `nohup` + Automator 实现。本项目针对新版微信的单实例检测机制，采用了更可靠的 **Bundle ID 修改方案**。

Inspired by [CLOUDUH/dual-wechat](https://github.com/CLOUDUH/dual-wechat), which uses `nohup` + Automator. This project adopts a more reliable **Bundle ID modification approach** to bypass newer WeChat's single-instance detection.

## 📄 License

[MIT](LICENSE)
