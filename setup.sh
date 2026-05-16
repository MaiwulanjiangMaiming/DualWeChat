#!/bin/bash
set -e

APP_NAME="DualWeChat"
SOURCE_APP="/Applications/WeChat.app"
TARGET_APP="/Applications/DualWeChat.app"
BUNDLE_ID="com.tencent.xinWeChat.dual"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

print_header() {
    printf "\n"
    printf "  ${BOLD}⚡ DualWeChat${RESET}  —  macOS 微信双开\n"
    printf "  ${DIM}github.com/MaiwulanjiangMaiming/DualWeChat${RESET}\n"
    printf "\n"
}

print_step() {
    printf "  %s  %s\n" "$1" "$2"
}

print_done() {
    printf "  ${DIM}✓${RESET} %s\n" "$1"
}

print_success() {
    printf "\n  ✅  %s\n" "$1"
}

print_warn() {
    printf "  ⚠️  %s\n" "$1"
}

print_error() {
    printf "  ❌  %s\n" "$1"
    exit 1
}

# ─────────────────────────────────────────

print_header

if [ ! -d "$SOURCE_APP" ]; then
    print_error "未检测到微信，请先从 App Store 或官网安装。"
fi

if [ -d "$TARGET_APP" ]; then
    print_warn "检测到已存在的 DualWeChat.app"
    read -p "  是否覆盖？ [y/N] " -n 1 -r
        printf "\n"
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            printf "  已取消。\n"
            exit 0
        fi
    sudo rm -rf "$TARGET_APP"
fi

# Step 1
print_step "1/5" "复制 WeChat.app → DualWeChat.app"
sudo cp -R "$SOURCE_APP" "$TARGET_APP"
print_done "复制完成"

# Step 2
print_step "2/5" "修改 Bundle Identifier"
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier $BUNDLE_ID" \
    "$TARGET_APP/Contents/Info.plist"
print_done "Bundle ID → $BUNDLE_ID"

# Step 3
print_step "3/5" "修改应用名称"
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleDisplayName $APP_NAME" \
    "$TARGET_APP/Contents/Info.plist"
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleName $APP_NAME" \
    "$TARGET_APP/Contents/Info.plist"

for strings_file in "$TARGET_APP"/Contents/Resources/*.lproj/InfoPlist.strings; do
    if [ -f "$strings_file" ]; then
        sudo /usr/libexec/PlistBuddy \
            -c "Set :CFBundleDisplayName $APP_NAME" "$strings_file" 2>/dev/null || true
        sudo /usr/libexec/PlistBuddy \
            -c "Set :CFBundleName $APP_NAME" "$strings_file" 2>/dev/null || true
    fi
done
print_done "名称 → DualWeChat"

# Step 4
print_step "4/5" "生成图标"

ICON_SCHEME="metal"

if command -v python3 &>/dev/null; then
    if python3 -c "from PIL import Image; import numpy" 2>/dev/null; then
        echo ""
        echo "  选择图标配色："
        echo ""
        echo "    1) Metal   — 金属黑"
        echo "    2) Aurora  — 冷蓝极光"
        echo "    3) Neon    — 紫粉霓虹"
        echo "    4) Lava    — 橙金熔岩"
        echo "    5) Matrix  — 黑客矩阵"
        echo "    0) 跳过"
        echo ""
        read -p "  请输入编号 [0-5，默认 1]: " -r SCHEME_CHOICE
        printf "\n"

        case "$SCHEME_CHOICE" in
            2) ICON_SCHEME="aurora" ;;
            3) ICON_SCHEME="neon" ;;
            4) ICON_SCHEME="lava" ;;
            5) ICON_SCHEME="matrix" ;;
            0) ICON_SCHEME="skip" ;;
            *) ICON_SCHEME="metal" ;;
        esac

        if [ "$ICON_SCHEME" != "skip" ]; then
            sudo chmod 666 "$TARGET_APP/Contents/Resources/AppIcon.icns"
            sudo python3 "$SCRIPT_DIR/generate_icon.py" "$TARGET_APP/Contents/Resources/AppIcon.icns" "$ICON_SCHEME" >/dev/null 2>&1
            print_done "图标 → $ICON_SCHEME"
        else
            print_done "使用原版图标"
        fi
    else
        print_warn "未安装 Pillow / numpy，跳过自定义图标"
        print_done "使用原版图标"
    fi
else
    print_warn "未安装 python3，跳过自定义图标"
    print_done "使用原版图标"
fi

# Step 5
print_step "5/5" "重新签名"
sudo codesign --force --deep --sign - "$TARGET_APP" 2>/dev/null
print_done "签名完成"

# Refresh
sudo touch "$TARGET_APP"
sudo killall Dock 2>/dev/null || true

# ─────────────────────────────────────────

printf "\n"
printf "  ${DIM}─────────────────────────────────────${RESET}\n"
printf "\n"
print_success "安装完成"
printf "\n"
printf "  WeChat      → 账号 1\n"
printf "  DualWeChat  → 账号 2\n"
printf "\n"
