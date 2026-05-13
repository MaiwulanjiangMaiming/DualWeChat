<div align="center">

# DualWeChat

**macOS 微信双开 · 一键安装**

通过复制应用并修改 Bundle Identifier，实现两个微信独立运行，<br>
互不干扰，无需终端，无后台进程残留。

[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## ✨ 特性

- **一键安装** — 运行一个脚本，自动完成所有配置
- **真正独立** — 不同 Bundle ID，两个微信互不干扰
- **金属图标** — 自动生成金属质感黑色图标，一眼区分
- **无终端残留** — 不需要保持终端窗口打开
- **可自定义** — 图标、名称均可自由修改

## 🔧 原理

> **核心思路：复制 `WeChat.app` 并修改其 `Bundle Identifier`。**

macOS 通过 `CFBundleIdentifier` 区分不同应用。新版微信会检测同 Bundle ID 的已有实例，拒绝启动第二个。因此：

| 步骤 | 说明 |
|------|------|
| 1. 复制 `WeChat.app` → `WeChat2.app` | 创建独立的应用副本 |
| 2. 修改 `CFBundleIdentifier` | `com.tencent.xinWeChat` → `com.tencent.xinWeChat.dual` |
| 3. 修改应用名称 | `WeChat` → `DualWeChat` |
| 4. 替换图标 | 生成金属黑质感图标（可选） |
| 5. 重新签名 | `codesign --force --deep --sign -` |

完成后两个应用在系统层面是完全独立的，可以同时登录不同账号。

### 与其他方案的对比

| 方案 | 原理 | 问题 |
|------|------|------|
| `nohup WeChat &` | 后台启动主程序 | ⚠️ 新版微信会检测已有实例，直接激活旧窗口 |
| `open -n WeChat.app` | 强制打开新实例 | ⚠️ 同上，单实例检测拦截 |
| **本方案（修改 Bundle ID）** | 复制应用并改 ID | ✅ 完美绕过单实例检测 |

## 🚀 安装

### 前置要求

- macOS 12.0+
- 已安装微信（从 App Store 或[官网](https://mac.weixin.qq.com/)）
- Python 3 + Pillow + numpy（用于生成自定义图标，可选）

### 一键安装

```bash
git clone https://github.com/MaiwulanjiangMaiming/DualWeChat.git
cd DualWeChat
chmod +x setup.sh
./setup.sh
```

安装过程中可能需要输入密码（用于 `sudo` 复制和签名）。

### 手动安装

如果你想自己操作每一步：

```bash
# 1. 复制微信
sudo cp -R /Applications/WeChat.app /Applications/WeChat2.app

# 2. 修改 Bundle ID
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier com.tencent.xinWeChat.dual" \
    /Applications/WeChat2.app/Contents/Info.plist

# 3. 修改显示名称
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleDisplayName DualWeChat" \
    /Applications/WeChat2.app/Contents/Info.plist
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleName DualWeChat" \
    /Applications/WeChat2.app/Contents/Info.plist

# 4. 修改 URL Scheme（可选）
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleURLTypes:0:CFBundleURLName com.tencent.xinWeChat.dual" \
    /Applications/WeChat2.app/Contents/Info.plist

# 5. 重新签名
sudo codesign --force --deep --sign - /Applications/WeChat2.app

# 6. 刷新 Dock
touch /Applications/WeChat2.app && killall Dock
```

### 自定义图标

如果你安装了 Python 3 和依赖：

```bash
pip3 install Pillow numpy
python3 generate_icon.py /Applications/WeChat2.app/Contents/Resources/AppIcon.icns
sudo codesign --force --deep --sign - /Applications/WeChat2.app
```

脚本会从原版微信图标生成金属质感黑色版本。你也可以手动替换任何 `.icns` 图标文件。

## 📱 使用

安装完成后，在启动台或 Spotlight 中可以看到两个应用：

| 应用 | 用途 |
|------|------|
| **WeChat** | 登录第一个账号 |
| **DualWeChat** | 登录第二个账号 |

将两个都拖到 Dock 栏，即可随时切换。

## ⚠️ 已知问题

- 点击微信 A 的通知横幅，可能跳转到微信 B 窗口（微信自身行为）
- 电脑休眠后重新唤醒，可能需要重新登录
- 重新登录时可能必须使用扫码方式
- 微信更新后需要重新运行 `setup.sh`（因为更新会覆盖 `WeChat.app`，但 `WeChat2.app` 不受影响）

## 🗑️ 卸载

```bash
sudo rm -rf /Applications/WeChat2.app
killall Dock
```

## 🙏 致谢

灵感来源于 [CLOUDUH/dual-wechat](https://github.com/CLOUDUH/dual-wechat)，该方案使用 `nohup` + Automator 实现。本项目针对新版微信的单实例检测机制，采用了更可靠的 **Bundle ID 修改方案**。

## 📄 License

[MIT](LICENSE)
