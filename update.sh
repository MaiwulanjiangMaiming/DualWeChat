#!/bin/bash
#
# DualWeChat updater
# https://github.com/MaiwulanjiangMaiming/DualWeChat
#
set -euo pipefail

SOURCE_APP="${DUALWECHAT_SOURCE_APP:-/Applications/WeChat.app}"
TARGET_APP="${DUALWECHAT_TARGET_APP:-/Applications/DualWeChat.app}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ASSUME_YES=0
CHECK_ONLY=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    ESC=$'\033'
    BOLD="${ESC}[1m"
    DIM="${ESC}[2m"
    RESET="${ESC}[0m"
    CYAN="${ESC}[38;2;79;227;255m"
    GREEN="${ESC}[38;2;48;209;88m"
    YELLOW="${ESC}[38;2;255;196;84m"
    RED="${ESC}[38;2;255;99;99m"
else
    BOLD="" DIM="" RESET="" CYAN="" GREEN="" YELLOW="" RED=""
fi

fail() {
    printf "\n  %s✗%s %s\n" "$RED" "$RESET" "$1" >&2
    exit 1
}

usage() {
    cat <<'EOF'
DualWeChat — 版本检查与更新

用法:
  ./update.sh [选项]

选项:
  -y, --yes     有更新时直接更新，不再询问
      --check   只检查版本；有更新时退出码为 10
  -h, --help    显示本帮助

说明:
  先更新原版微信，再运行本脚本。脚本会对比两个应用的
  CFBundleVersion，调用 setup.sh 重建 DualWeChat；重建时
  会沿用当前副本的图标。

退出码:
  0   已是最新版本（或用户取消）
  10  检测到新版本（仅 --check）
  1   检查失败
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1; shift ;;
        --check) CHECK_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "未知参数：$1（使用 --help 查看帮助）" ;;
    esac
done

plist_read() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null || true
}

version_gt() {
    [ "$1" != "$2" ] || return 1
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]
}

confirm() {
    local prompt="$1"
    local reply=""
    if [ ! -t 0 ]; then
        fail "当前不是交互式终端，请加 --yes 或使用 --check。"
    fi
    read -r -p "  $prompt" -n 1 reply || true
    printf "\n"
    # 清掉输入缓冲里的回车（macOS bash 3.2 不支持小数超时）
    if [ -n "$reply" ]; then
        IFS= read -r -t 1 _ || true
    fi
    [[ "$reply" =~ ^[Yy]$ ]]
}

printf "\n"
printf "  %s🔄 DualWeChat%s  %s版本检查%s\n" "$BOLD$CYAN" "$RESET" "$DIM" "$RESET"
printf "  %sgithub.com/MaiwulanjiangMaiming/DualWeChat%s\n" "$DIM" "$RESET"
printf "\n"

if [ ! -d "$SOURCE_APP" ]; then
    fail "未检测到微信，请先从 App Store 或官网安装。"
fi
if [ ! -d "$TARGET_APP" ]; then
    fail "未检测到 DualWeChat，请先运行 ./setup.sh 安装。"
fi

SRC_VER="$(plist_read CFBundleVersion "$SOURCE_APP/Contents/Info.plist")"
DST_VER="$(plist_read CFBundleVersion "$TARGET_APP/Contents/Info.plist")"
SRC_SHORT="$(plist_read CFBundleShortVersionString "$SOURCE_APP/Contents/Info.plist")"
DST_SHORT="$(plist_read CFBundleShortVersionString "$TARGET_APP/Contents/Info.plist")"

if [ -z "$SRC_VER" ] || [ -z "$DST_VER" ]; then
    fail "无法读取版本号，请确认两个应用完整。"
fi

printf "  WeChat       %s (%s)\n" "${SRC_SHORT:-未知}" "$SRC_VER"
printf "  DualWeChat   %s (%s)\n" "${DST_SHORT:-未知}" "$DST_VER"
printf "\n"

if [ "$SRC_VER" = "$DST_VER" ]; then
    printf "  %s✓ 已是最新版本%s\n" "$GREEN" "$RESET"
    printf "  %s两个应用版本一致，无需更新。%s\n\n" "$DIM" "$RESET"

    if [ "$CHECK_ONLY" -eq 1 ]; then
        exit 0
    fi
    if [ "$ASSUME_YES" -eq 1 ]; then
        exit 0
    fi

    if confirm "重新安装 / 更换图标？[y/N] "; then
        exec bash "$SCRIPT_DIR/setup.sh" --yes --keep-icon
    fi
    printf "  已跳过。\n\n"
    exit 0
fi

if version_gt "$SRC_VER" "$DST_VER"; then
    printf "  %s↑ 发现新版本%s  %s→%s\n\n" "$YELLOW" "$RESET" \
        "${DST_SHORT:-$DST_VER}" → "${SRC_SHORT:-$SRC_VER}"

    if [ "$CHECK_ONLY" -eq 1 ]; then
        printf "  %s可更新：%s (%s) → %s (%s)%s\n\n" "$DIM" \
            "$DST_SHORT" "$DST_VER" "$SRC_SHORT" "$SRC_VER" "$RESET"
        exit 10
    fi

    if [ "$ASSUME_YES" -eq 0 ] && ! confirm "更新 DualWeChat？[y/N] "; then
        printf "  已跳过。\n\n"
        exit 0
    fi

    printf "\n  %s即将重建 DualWeChat，运行中的副本会自动退出。%s\n" "$DIM" "$RESET"
    exec bash "$SCRIPT_DIR/setup.sh" --yes --keep-icon
fi

# 原版比副本旧：可能刚回滚，或副本来自更新的测试版
printf "  %s! 原版微信的版本低于 DualWeChat%s\n\n" "$YELLOW" "$RESET"
printf "  %s原版 %s (%s)  <  副本 %s (%s)%s\n\n" "$DIM" \
    "$SRC_SHORT" "$SRC_VER" "$DST_SHORT" "$DST_VER" "$RESET"

if [ "$CHECK_ONLY" -eq 1 ]; then
    exit 0
fi
if [ "$ASSUME_YES" -eq 1 ]; then
    exit 0
fi

if confirm "仍要按原版重装（相当于降级）？[y/N] "; then
    exec bash "$SCRIPT_DIR/setup.sh" --yes --keep-icon
fi
printf "  已跳过。\n\n"
exit 0
