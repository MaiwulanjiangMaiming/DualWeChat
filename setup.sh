#!/bin/bash
set -e

APP_NAME="DualWeChat"
SOURCE_APP="/Applications/WeChat.app"
TARGET_APP="/Applications/DualWeChat.app"
BUNDLE_ID="com.tencent.xinWeChat.dual"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         DualWeChat Installer             ║${NC}"
echo -e "${CYAN}║     macOS 微信双开 · 一键安装            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

if [ ! -d "$SOURCE_APP" ]; then
    error "未检测到微信，请先从 App Store 或官网安装微信。"
fi

if [ -d "$TARGET_APP" ]; then
    warn "检测到已存在的 $TARGET_APP"
    read -p "是否覆盖？[y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "已取消安装。"
        exit 0
    fi
    sudo rm -rf "$TARGET_APP"
fi

info "正在复制 WeChat.app → DualWeChat.app ..."
sudo cp -R "$SOURCE_APP" "$TARGET_APP"
ok "复制完成"

info "正在修改 Bundle Identifier ..."
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier $BUNDLE_ID" \
    "$TARGET_APP/Contents/Info.plist"
ok "Bundle ID → $BUNDLE_ID"

info "正在修改应用名称 ..."
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleDisplayName $APP_NAME" \
    "$TARGET_APP/Contents/Info.plist"
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleName $APP_NAME" \
    "$TARGET_APP/Contents/Info.plist"
ok "应用名称 → $APP_NAME"

info "正在修改 URL Scheme Bundle ID ..."
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleURLTypes:0:CFBundleURLName $BUNDLE_ID" \
    "$TARGET_APP/Contents/Info.plist" 2>/dev/null || true
ok "URL Scheme 已更新"

if command -v python3 &>/dev/null; then
    if python3 -c "from PIL import Image; import numpy" 2>/dev/null; then
        info "正在生成金属质感图标 ..."
        sudo chmod 666 "$TARGET_APP/Contents/Resources/AppIcon.icns"
        sudo python3 "$SCRIPT_DIR/generate_icon.py" "$TARGET_APP/Contents/Resources/AppIcon.icns"
        if [ $? -eq 0 ]; then
            ok "金属图标已应用"
        else
            warn "图标生成失败，将使用原版图标"
        fi
    else
        warn "未检测到 Pillow / numpy，跳过自定义图标"
        warn "可通过 pip3 install Pillow numpy 安装后重新运行"
    fi
else
    warn "未检测到 python3，跳过自定义图标"
fi

info "正在重新签名应用 ..."
sudo codesign --force --deep --sign - "$TARGET_APP" 2>/dev/null
ok "签名完成"

info "正在刷新 Dock 缓存 ..."
sudo touch "$TARGET_APP"
sudo killall Dock 2>/dev/null || true

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✅ 安装完成！                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}WeChat${NC}      → 登录第一个账号"
echo -e "  ${CYAN}DualWeChat${NC}   → 登录第二个账号"
echo ""
echo -e "  两个应用互相独立，可同时运行。"
echo ""
