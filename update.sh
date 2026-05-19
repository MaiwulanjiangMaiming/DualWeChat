#!/bin/bash
set -e

SOURCE_APP="/Applications/WeChat.app"
TARGET_APP="/Applications/DualWeChat.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

if [ ! -d "$SOURCE_APP" ]; then
    printf "  ❌  未检测到微信\n"
    exit 1
fi

if [ ! -d "$TARGET_APP" ]; then
    printf "  ❌  未检测到 DualWeChat，请先运行 ./setup.sh\n"
    exit 1
fi

SRC_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$SOURCE_APP/Contents/Info.plist")
DST_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$TARGET_APP/Contents/Info.plist")
SRC_SHORT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SOURCE_APP/Contents/Info.plist")
DST_SHORT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$TARGET_APP/Contents/Info.plist")

printf "\n"
printf "  ${BOLD}🔄 DualWeChat 版本检查${RESET}\n"
printf "\n"
printf "  WeChat       %s (%s)\n" "$SRC_SHORT" "$SRC_VER"
printf "  DualWeChat   %s (%s)\n" "$DST_SHORT" "$DST_VER"
printf "\n"

if [ "$SRC_VER" = "$DST_VER" ]; then
    printf "  ✅  版本一致，无需更新。\n"
    printf "\n"
    exit 0
fi

printf "  ⚠️  检测到新版本，是否更新？\n"
read -p "  [y/N] " -n 1 -r
printf "\n"

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "  已跳过。\n"
    printf "\n"
    exit 0
fi

exec "$SCRIPT_DIR/setup.sh"
