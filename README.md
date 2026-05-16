<div align="center">

# DualWeChat

**macOS 微信双开 · 一键安装**

通过复制应用并修改 Bundle Identifier，实现两个微信独立运行，互不干扰。

[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[English](README_EN.md)

</div>

---

## 快速开始

```bash
git clone https://github.com/MaiwulanjiangMaiming/DualWeChat.git
cd DualWeChat
chmod +x setup.sh
./setup.sh
```

安装时会提示选择图标配色，支持 5 种主题：

| 编号 | 名称 | 风格 |
|-----|------|------|
| 1 | Metal / 金属 | 金属黑质感 |
| 2 | Aurora / 极光 | 冷蓝极光感 |
| 3 | Neon / 霓虹 | 紫粉霓虹感 |
| 4 | Lava / 熔岩 | 橙金烈焰感 |
| 5 | Matrix / 矩阵 | 黑客终端感 |

安装完成后，启动台会出现 **DualWeChat**，与原版 **WeChat** 同时运行，登录不同账号即可。

---

## 为什么需要这个项目

macOS 上的微信会检测是否已有实例在运行。如果直接双击微信图标两次，第二次只会激活已打开的窗口，不会启动第二个微信。

本项目通过复制一份微信应用，并修改其 Bundle Identifier，让系统认为这是两个完全不同的应用，从而绕过单实例检测。

### 与其他方案的对比

| 方案 | 原理 | 效果 |
|------|------|------|
| `nohup WeChat &` | 后台启动 | ❌ 新版微信会检测已有实例 |
| `open -n WeChat.app` | 强制新实例 | ❌ 同上，被拦截 |
| **修改 Bundle ID** | 复制应用并改 ID | ✅ 完美绕过检测 |

---

## 手动安装（可选）

如果你不想用脚本，可以手动执行每一步：

```bash
# 复制微信
sudo cp -R /Applications/WeChat.app /Applications/DualWeChat.app

# 修改 Bundle ID
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier com.tencent.xinWeChat.dual" \
    /Applications/DualWeChat.app/Contents/Info.plist

# 修改名称
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleDisplayName DualWeChat" \
    /Applications/DualWeChat.app/Contents/Info.plist
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleName DualWeChat" \
    /Applications/DualWeChat.app/Contents/Info.plist

# 重新签名
sudo codesign --force --deep --sign - /Applications/DualWeChat.app

# 刷新 Dock
sudo touch /Applications/DualWeChat.app && sudo killall Dock
```

---

## 自定义图标

安装脚本已内置 5 种配色方案。也可以手动指定：

```bash
pip3 install Pillow numpy
python3 generate_icon.py /Applications/DualWeChat.app/Contents/Resources/AppIcon.icns aurora
sudo codesign --force --deep --sign - /Applications/DualWeChat.app
```

可选配色：`metal`, `aurora`, `neon`, `lava`, `matrix`

也可以直接替换任意 `.icns` 图标文件。

---

## 使用说明

- **WeChat** — 登录第一个账号
- **DualWeChat** — 登录第二个账号

两个应用的通知是独立的，图标不同，一眼就能区分。通知设置可在系统设置中分别配置。

> **微信更新后**：由于更新会可能覆盖原版 `WeChat.app`，建议更新后重新运行 `./setup.sh` 生成新的 `DualWeChat.app`。

---

## 卸载

```bash
sudo rm -rf /Applications/DualWeChat.app
```

---

## 致谢

灵感来源于 [CLOUDUH/dual-wechat](https://github.com/CLOUDUH/dual-wechat)。本项目针对新版微信的单实例检测机制，采用了更可靠的 Bundle ID 修改方案。

## License

[MIT](LICENSE)
