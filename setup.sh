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

# 退出正在运行的 DualWeChat（旧实例在启动时已加载旧图标，不重启不会更新）
NEED_RELAUNCH=0
if pgrep -f "$TARGET_APP" >/dev/null 2>&1; then
    print_step "0/5" "退出正在运行的 DualWeChat"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
        pgrep -f "$TARGET_APP" >/dev/null 2>&1 || break
        sleep 0.5
    done
    if pgrep -f "$TARGET_APP" >/dev/null 2>&1; then
        print_warn "DualWeChat 未完全退出，将继续更新（完成后请手动重启）"
    else
        NEED_RELAUNCH=1
        print_done "已退出 DualWeChat"
    fi
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
print_step "1/5" "复制 WeChat.app -> DualWeChat.app"
sudo cp -R "$SOURCE_APP" "$TARGET_APP"
# 归还给当前用户，避免 root 属主导致应用内更新/后续维护失败
sudo chown -R "$USER:$(id -gn "$USER")" "$TARGET_APP"
print_done "复制完成"

# Step 2
print_step "2/5" "修改 Bundle Identifier"
sudo /usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier $BUNDLE_ID" \
    "$TARGET_APP/Contents/Info.plist"
print_done "Bundle ID -> $BUNDLE_ID"

# 重签名后 Sparkle 无法通过签名校验安装应用内更新（且更新会覆盖双开修改），
# 禁用应用内自动更新，升级统一走 ./update.sh
sudo /usr/libexec/PlistBuddy \
    -c "Add :SUEnableAutomaticChecks bool false" \
    "$TARGET_APP/Contents/Info.plist" 2>/dev/null || true
sudo /usr/libexec/PlistBuddy \
    -c "Set :SUEnableAutomaticChecks false" \
    "$TARGET_APP/Contents/Info.plist"
sudo /usr/libexec/PlistBuddy \
    -c "Add :SUAllowsAutomaticUpdates bool false" \
    "$TARGET_APP/Contents/Info.plist" 2>/dev/null || true
sudo /usr/libexec/PlistBuddy \
    -c "Set :SUAllowsAutomaticUpdates false" \
    "$TARGET_APP/Contents/Info.plist"
print_done "已禁用应用内自动更新（升级请用 ./update.sh）"

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
            # 以当前用户生成到临时目录（sudo 环境下 python 可能没有 Pillow/numpy），再安装进 app
            ICON_TMP_DIR="$(mktemp -d)"
            if python3 "$SCRIPT_DIR/generate_icon.py" "$ICON_TMP_DIR/AppIcon.icns" "$ICON_SCHEME" \
                && sudo cp "$ICON_TMP_DIR/AppIcon.icns" "$TARGET_APP/Contents/Resources/AppIcon.icns"; then
                # macOS 26 优先使用 Assets.car 中 CFBundleIconName 指向的原版图标，
                # 删除该键强制系统回退到 CFBundleIconFile（即刚替换的 AppIcon.icns）
                sudo /usr/libexec/PlistBuddy \
                    -c "Delete :CFBundleIconName" \
                    "$TARGET_APP/Contents/Info.plist" 2>/dev/null || true
                print_done "图标 -> $ICON_SCHEME"
            else
                print_warn "图标生成失败，保留原版图标"
            fi
            rm -rf "$ICON_TMP_DIR"
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
if ! sudo codesign --force --deep --sign - "$TARGET_APP" >/dev/null 2>/tmp/dualwechat_sign_err.log; then
    print_error "签名失败：$(cat /tmp/dualwechat_sign_err.log)"
fi
rm -f /tmp/dualwechat_sign_err.log
print_done "签名完成"

# Refresh
sudo touch "$TARGET_APP"
# macOS 26 (Tahoe) 图标缓存顽固，需清理 iconservices 缓存才能让 Dock/访达显示新图标
ICON_CACHE_DIR="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)"
if [ -n "$ICON_CACHE_DIR" ] && [ -d "$ICON_CACHE_DIR" ]; then
    sudo rm -rf "${ICON_CACHE_DIR%/}/com.apple.iconservices" \
                "${ICON_CACHE_DIR%/}/com.apple.iconservicesagent" 2>/dev/null || true
fi
sudo killall Dock 2>/dev/null || true
sudo killall Finder 2>/dev/null || true

# 更新前在运行则重新启动（新实例启动时加载新图标，Dock 立即显示）
if [ "$NEED_RELAUNCH" = "1" ]; then
    if open "$TARGET_APP" 2>/dev/null; then
        print_done "已重新启动 DualWeChat"
    fi
fi

# ─────────────────────────────────────────

printf "\n"
printf "  ${DIM}─────────────────────────────────────${RESET}\n"
printf "\n"
print_success "安装完成"
printf "\n"
printf "  WeChat      -> 账号 1\n"
printf "  DualWeChat  -> 账号 2\n"
printf "\n"
printf "  ${DIM}升级方式：先更新原版微信，再运行 ./update.sh${RESET}\n"
printf "\n"
