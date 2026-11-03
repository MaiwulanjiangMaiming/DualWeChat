#!/bin/bash
#
# DualWeChat installer for macOS
# https://github.com/MaiwulanjiangMaiming/DualWeChat
#
set -euo pipefail

APP_NAME="DualWeChat"
SOURCE_APP="${DUALWECHAT_SOURCE_APP:-/Applications/WeChat.app}"
TARGET_APP="${DUALWECHAT_TARGET_APP:-/Applications/DualWeChat.app}"
TARGET_DIR="$(dirname "$TARGET_APP")"
BUNDLE_ID="com.tencent.xinWeChat.dual"
SOURCE_ICON="$SOURCE_APP/Contents/Resources/AppIcon.icns"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCHEME=""
ASSUME_YES=0
SKIP_ICON=0
KEEP_ICON=0
CHECK_ONLY=0
NEED_RELAUNCH=0
PRESERVED_ICON=""

# ── colors ────────────────────────────────────────────────────────────────

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    ESC=$'\033'
    BOLD="${ESC}[1m"
    DIM="${ESC}[2m"
    RESET="${ESC}[0m"
    CYAN="${ESC}[38;2;79;227;255m"
    GREEN="${ESC}[38;2;48;209;88m"
    YELLOW="${ESC}[38;2;255;196;84m"
    RED="${ESC}[38;2;255;99;99m"
    DOT_METAL="${ESC}[38;2;220;226;235m"
    DOT_AURORA="${ESC}[38;2;79;227;255m"
    DOT_NEON="${ESC}[38;2;198;60;255m"
    DOT_LAVA="${ESC}[38;2;255;140;40m"
    DOT_MATRIX="${ESC}[38;2;40;255;150m"
else
    BOLD="" DIM="" RESET="" CYAN="" GREEN="" YELLOW="" RED=""
    DOT_METAL="" DOT_AURORA="" DOT_NEON="" DOT_LAVA="" DOT_MATRIX=""
fi

TMP_DIR=""
SUDO_KEEPALIVE_PID=""

cleanup() {
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

on_error() {
    local code=$?
    printf "\n  %s✗ 安装中断%s（第 %s 行，退出码 %s）\n" "$RED" "$RESET" "$1" "$code" >&2
    printf "  %s请检查上方输出；如仍无法解决，请附版本信息提交 issue。%s\n" "$DIM" "$RESET" >&2
}
trap 'on_error $LINENO' ERR

# ── output ────────────────────────────────────────────────────────────────

hr() {
    printf "  %s────────────────────────────────────────────%s\n" "$DIM" "$RESET"
}

header() {
    printf "\n"
    printf "  %s⚡ DualWeChat%s  %s—  macOS 微信双开%s\n" "$BOLD$CYAN" "$RESET" "$DIM" "$RESET"
    printf "  %sgithub.com/MaiwulanjiangMaiming/DualWeChat%s\n" "$DIM" "$RESET"
    printf "\n"
}

step() {
    printf "\n  %s▸%s %s%s%s  %s\n" "$CYAN" "$RESET" "$BOLD" "$1" "$RESET" "$2"
}

ok() {
    printf "    %s✓%s %s%s%s\n" "$GREEN" "$RESET" "$DIM" "$1" "$RESET"
}

warn() {
    printf "    %s!%s %s\n" "$YELLOW" "$RESET" "$1"
}

fail() {
    printf "\n  %s✗%s %s\n" "$RED" "$RESET" "$1" >&2
    exit 1
}

usage() {
    cat <<'EOF'
DualWeChat — macOS 微信双开

用法:
  ./setup.sh [选项]

选项:
  -s, --scheme <name>   直接指定图标主题，跳过选择菜单
      --keep-icon       重建时沿用当前副本的图标（更新时默认行为）
      --no-icon         保留微信原版图标
  -y, --yes             覆盖已有副本时不再询问
      --check           只检查环境并显示版本，不做任何修改
  -h, --help            显示本帮助

主题:
  metal (金属黑)  aurora (冷蓝极光)  neon (紫粉霓虹)
  lava (橙金熔岩)  matrix (黑客矩阵)

示例:
  ./setup.sh --scheme aurora
  ./setup.sh --check

环境变量:
  DUALWECHAT_SOURCE_APP  原版微信路径（默认 /Applications/WeChat.app）
  DUALWECHAT_TARGET_APP  副本路径（默认 /Applications/DualWeChat.app）
  NO_COLOR=1             关闭彩色输出
EOF
}

# ── helpers ───────────────────────────────────────────────────────────────

plist_read() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null || true
}

is_scheme() {
    case "$1" in
        metal|aurora|neon|lava|matrix) return 0 ;;
        *) return 1 ;;
    esac
}

confirm() {
    local prompt="$1"
    local reply=""
    if [ ! -t 0 ]; then
        fail "当前不是交互式终端，请加 --yes 继续。"
    fi
    read -r -p "  $prompt" -n 1 reply || true
    printf "\n"
    # 清掉输入缓冲里的回车（macOS bash 3.2 不支持小数超时）
    if [ -n "$reply" ]; then
        IFS= read -r -t 1 _ || true
    fi
    [[ "$reply" =~ ^[Yy]$ ]]
}

choose_scheme() {
    if [ -n "$SCHEME" ]; then
        return 0
    fi

    if [ ! -t 0 ]; then
        SCHEME="metal"
        warn "非交互环境，使用默认主题 metal"
        return 0
    fi

    printf "\n    %s选择图标配色%s\n\n" "$BOLD" "$RESET"
    printf "      1) %s●%s  Metal    金属黑\n" "$DOT_METAL" "$RESET"
    printf "      2) %s●%s  Aurora   冷蓝极光  %s（推荐）%s\n" "$DOT_AURORA" "$RESET" "$DIM" "$RESET"
    printf "      3) %s●%s  Neon     紫粉霓虹\n" "$DOT_NEON" "$RESET"
    printf "      4) %s●%s  Lava     橙金熔岩\n" "$DOT_LAVA" "$RESET"
    printf "      5) %s●%s  Matrix   黑客矩阵\n" "$DOT_MATRIX" "$RESET"
    printf "      0)    保留原版图标\n\n"

    local choice=""
    read -r -p "    输入编号 [0-5，回车默认 1]: " choice || true
    printf "\n"

    case "$choice" in
        0) SKIP_ICON=1 ;;
        2) SCHEME="aurora" ;;
        3) SCHEME="neon" ;;
        4) SCHEME="lava" ;;
        5) SCHEME="matrix" ;;
        *) SCHEME="metal" ;;
    esac
}

print_check() {
    local macos_version arch wechat_ver wechat_short dual_ver dual_short
    local py_info python_ok="否"

    macos_version="$(sw_vers -productVersion 2>/dev/null || echo "未知")"
    arch="$(uname -m)"
    wechat_short="$(plist_read CFBundleShortVersionString "$SOURCE_APP/Contents/Info.plist")"
    wechat_ver="$(plist_read CFBundleVersion "$SOURCE_APP/Contents/Info.plist")"
    dual_short="$(plist_read CFBundleShortVersionString "$TARGET_APP/Contents/Info.plist")"
    dual_ver="$(plist_read CFBundleVersion "$TARGET_APP/Contents/Info.plist")"

    printf "  %s环境检查%s\n\n" "$BOLD" "$RESET"
    printf "  macOS        %s (%s)\n" "$macos_version" "$arch"

    if [ -d "$SOURCE_APP" ]; then
        printf "  WeChat       %s (%s)  %s\n" "${wechat_short:-未知}" "${wechat_ver:-未知}" "$SOURCE_APP"
    else
        printf "  WeChat       %s未检测到%s  %s\n" "$RED" "$RESET" "$SOURCE_APP"
    fi

    if [ -d "$TARGET_APP" ]; then
        printf "  DualWeChat   %s (%s)  %s\n" "${dual_short:-未知}" "${dual_ver:-未知}" "$TARGET_APP"
    else
        printf "  DualWeChat   %s未安装%s\n" "$DIM" "$RESET"
    fi

    if command -v python3 >/dev/null 2>&1; then
        py_info="$(python3 -c 'import sys; print("Python " + ".".join(map(str, sys.version_info[:3])))' 2>/dev/null || echo "Python 3")"
        if python3 -c "import PIL, numpy" >/dev/null 2>&1; then
            python_ok="Pillow + numpy 已安装"
        else
            python_ok="缺少 Pillow / numpy（自定义图标不可用）"
        fi
        printf "  图标生成     %s，%s\n" "$py_info" "$python_ok"
    else
        printf "  图标生成     %s未安装 python3（将保留原版图标）%s\n" "$YELLOW" "$RESET"
    fi

    local free_gb
    free_gb="$(df -Pk "$TARGET_DIR" 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1048576}')"
    printf "  磁盘可用     %s GB\n" "${free_gb:-未知}"
    printf "\n"
}

# ── argument parsing ──────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        -s|--scheme)
            [ $# -ge 2 ] || fail "--scheme 需要一个主题名称。"
            SCHEME="$2"
            shift 2
            ;;
        --scheme=*)
            SCHEME="${1#*=}"
            shift
            ;;
        --no-icon)
            SKIP_ICON=1
            shift
            ;;
        --keep-icon)
            KEEP_ICON=1
            shift
            ;;
        -y|--yes)
            ASSUME_YES=1
            shift
            ;;
        --check)
            CHECK_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "未知参数：$1（使用 --help 查看帮助）"
            ;;
    esac
done

if [ -n "$SCHEME" ] && ! is_scheme "$SCHEME"; then
    fail "未知主题：${SCHEME}（可选：metal, aurora, neon, lava, matrix）"
fi

# 显式指定主题时，以主题为准
if [ -n "$SCHEME" ]; then
    KEEP_ICON=0
fi

header

# ── preflight ─────────────────────────────────────────────────────────────

if [ "$CHECK_ONLY" -eq 1 ]; then
    print_check
    [ -d "$SOURCE_APP" ] || exit 1
    exit 0
fi

[ "$(uname -s)" = "Darwin" ] || fail "DualWeChat 仅支持 macOS。"

if [ ! -d "$SOURCE_APP" ]; then
    fail "未检测到微信，请先从 App Store 或官网安装。"
fi
if [ ! -r "$SOURCE_APP/Contents/Info.plist" ]; then
    fail "无法读取微信的 Info.plist，请确认应用完整。"
fi

MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo "未知")"
printf "  %s即将安装 DualWeChat%s\n\n" "$DIM" "$RESET"
printf "  WeChat       %s (%s)\n" \
    "$(plist_read CFBundleShortVersionString "$SOURCE_APP/Contents/Info.plist")" \
    "$(plist_read CFBundleVersion "$SOURCE_APP/Contents/Info.plist")"
printf "  macOS        %s (%s)\n" "$MACOS_VERSION" "$(uname -m)"

NEED_KB="$(du -sk "$SOURCE_APP" | awk '{print $1}')"
FREE_KB="$(df -Pk "$TARGET_DIR" | awk 'NR==2 {print $4}')"
if [ -n "$NEED_KB" ] && [ -n "$FREE_KB" ]; then
    if [ "$FREE_KB" -lt "$NEED_KB" ]; then
        fail "磁盘空间不足：复制需要约 $((NEED_KB / 1024)) MB，当前可用 $((FREE_KB / 1024)) MB。"
    elif [ "$FREE_KB" -lt $((NEED_KB * 12 / 10)) ]; then
        warn "磁盘剩余空间偏紧，建议至少预留 $((NEED_KB * 12 / 10240)) MB。"
    fi
fi

if [ -d "$TARGET_APP" ]; then
    warn "已存在 $TARGET_APP"
    if [ "$ASSUME_YES" -eq 0 ]; then
        if ! confirm "覆盖安装？[y/N] "; then
            printf "  已取消。\n"
            exit 0
        fi
    fi
fi

printf "\n  %s需要管理员权限写入 %s，可能会提示输入密码。%s\n" "$DIM" "$TARGET_DIR" "$RESET"
if ! sudo -v; then
    fail "无法获取管理员权限，安装已取消。"
fi

# 保持 sudo 时间戳，避免安装过程中反复要求输入密码
( while true; do
    sudo -n true 2>/dev/null || true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit 0
  done ) &
SUDO_KEEPALIVE_PID=$!
disown "$SUDO_KEEPALIVE_PID" 2>/dev/null || true

# ── 0. quit running copy ──────────────────────────────────────────────────

if pgrep -f "$TARGET_APP" >/dev/null 2>&1; then
    step "0/6" "退出正在运行的 DualWeChat"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in $(seq 1 24); do
        pgrep -f "$TARGET_APP" >/dev/null 2>&1 || break
        sleep 0.25
    done
    if pgrep -f "$TARGET_APP" >/dev/null 2>&1; then
        warn "未能自动退出，将继续更新（完成后请手动重启）"
    else
        NEED_RELAUNCH=1
        ok "已退出 DualWeChat"
    fi
fi

# 更新场景：先把旧副本的图标留在临时目录，重建后还原
if [ "$KEEP_ICON" -eq 1 ] && [ "$SKIP_ICON" -eq 0 ] \
    && [ -s "$TARGET_APP/Contents/Resources/AppIcon.icns" ]; then
    TMP_DIR="${TMP_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/dualwechat.XXXXXX")}"
    if cp "$TARGET_APP/Contents/Resources/AppIcon.icns" "$TMP_DIR/AppIcon.prev.icns" 2>/dev/null; then
        PRESERVED_ICON="$TMP_DIR/AppIcon.prev.icns"
    fi
fi

if [ -d "$TARGET_APP" ]; then
    sudo rm -rf "$TARGET_APP"
fi

# ── 1. copy ───────────────────────────────────────────────────────────────

step "1/6" "复制微信应用"
sudo cp -R "$SOURCE_APP" "$TARGET_APP"
# 归还给当前用户，避免 root 属主影响后续维护
sudo chown -R "$(id -u):$(id -g)" "$TARGET_APP"
APP_SIZE="$(du -sh "$TARGET_APP" | awk '{print $1}')"
ok "复制完成（${APP_SIZE}）"

# ── 2. bundle identity + disable in-app updater ───────────────────────────

step "2/6" "写入独立身份"
PLIST="$TARGET_APP/Contents/Info.plist"

sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
ok "Bundle ID → $BUNDLE_ID"

# 重签名后 Sparkle 无法通过签名校验；且应用内更新会覆盖双开修改
set_bool() {
    local key="$1"
    sudo /usr/libexec/PlistBuddy -c "Add :$key bool false" "$PLIST" 2>/dev/null || true
    sudo /usr/libexec/PlistBuddy -c "Set :$key false" "$PLIST"
}
set_bool "SUEnableAutomaticChecks"
set_bool "SUAllowsAutomaticUpdates"
set_bool "SUAutomaticallyUpdate"
ok "已禁用应用内更新（升级请用 ./update.sh）"

# ── 3. name ───────────────────────────────────────────────────────────────

step "3/6" "重命名应用"
sudo /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$PLIST"
sudo /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$PLIST"

for strings_file in "$TARGET_APP"/Contents/Resources/*.lproj/InfoPlist.strings; do
    [ -f "$strings_file" ] || continue
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$strings_file" 2>/dev/null || true
    sudo /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$strings_file" 2>/dev/null || true
done
ok "名称 → DualWeChat"

# ── 4. icon ───────────────────────────────────────────────────────────────

step "4/6" "生成图标"

if [ "$SKIP_ICON" -eq 1 ]; then
    ok "保留微信原版图标"
elif [ -n "$PRESERVED_ICON" ]; then
    sudo cp "$PRESERVED_ICON" "$TARGET_APP/Contents/Resources/AppIcon.icns"
    sudo chmod 644 "$TARGET_APP/Contents/Resources/AppIcon.icns"
    if /usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$PLIST" >/dev/null 2>&1; then
        sudo /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST"
    fi
    ok "沿用上一版图标"
else
    choose_scheme

    if [ "$SKIP_ICON" -eq 1 ]; then
        ok "保留微信原版图标"
    elif ! command -v python3 >/dev/null 2>&1; then
        warn "未安装 python3，保留原版图标（可安装后重跑）"
    elif ! python3 -c "import PIL, numpy" >/dev/null 2>&1; then
        warn "缺少 Pillow / numpy，保留原版图标"
        warn "安装：pip3 install Pillow numpy"
    elif [ ! -f "$SOURCE_ICON" ]; then
        warn "未找到 ${SOURCE_ICON}，保留原版图标"
    else
        TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dualwechat.XXXXXX")"
        if python3 "$SCRIPT_DIR/generate_icon.py" "$TMP_DIR/AppIcon.icns" "$SCHEME" \
            >"$TMP_DIR/icon.log" 2>&1 && [ -s "$TMP_DIR/AppIcon.icns" ]; then
            sudo cp "$TMP_DIR/AppIcon.icns" "$TARGET_APP/Contents/Resources/AppIcon.icns"
            sudo chmod 644 "$TARGET_APP/Contents/Resources/AppIcon.icns"
            # macOS 26 优先使用 Assets.car 中 CFBundleIconName 指向的原版图标
            if /usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$PLIST" >/dev/null 2>&1; then
                sudo /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST"
                ok "已移除 Assets.car 图标声明"
            fi
            ok "图标 → $SCHEME"
        else
            warn "图标生成失败，保留原版图标"
            if [ -s "$TMP_DIR/icon.log" ]; then
                warn "$(tail -n 1 "$TMP_DIR/icon.log")"
            fi
        fi
    fi
fi

# ── 5. re-sign ────────────────────────────────────────────────────────────

step "5/6" "重新签名"
if [ -z "$TMP_DIR" ]; then
    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dualwechat.XXXXXX")"
fi
if ! sudo codesign --force --deep --sign - "$TARGET_APP" >/dev/null 2>"$TMP_DIR/sign.log"; then
    warn "$(tail -n 2 "$TMP_DIR/sign.log")"
    fail "签名失败，请检查上方错误信息。"
fi
if ! codesign --verify --deep --strict "$TARGET_APP" >/dev/null 2>&1; then
    warn "签名校验有警告，通常不影响启动"
fi
ok "ad-hoc 签名完成"

# ── 6. refresh caches ─────────────────────────────────────────────────────

step "6/6" "刷新图标缓存"
sudo touch "$TARGET_APP"

ICON_CACHE_DIR="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null || true)"
if [ -n "$ICON_CACHE_DIR" ] && [ -d "$ICON_CACHE_DIR" ]; then
    rm -rf "${ICON_CACHE_DIR%/}/com.apple.iconservices" \
           "${ICON_CACHE_DIR%/}/com.apple.iconservicesagent" 2>/dev/null || true
fi
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
ok "Dock / Finder 已刷新"

if [ "$NEED_RELAUNCH" -eq 1 ]; then
    sleep 1
    if open "$TARGET_APP" >/dev/null 2>&1; then
        ok "已重新启动 DualWeChat"
    else
        warn "请手动启动 DualWeChat"
    fi
fi

# ── summary ───────────────────────────────────────────────────────────────

printf "\n"
hr
printf "\n  %s✓ 安装完成%s  %s用时 %ss%s\n\n" "$GREEN$BOLD" "$RESET" "$DIM" "$SECONDS" "$RESET"
printf "  WeChat      %s→%s 账号 1\n" "$DIM" "$RESET"
printf "  DualWeChat  %s→%s 账号 2\n\n" "$DIM" "$RESET"
printf "  %s版本 %s · %s · 占用 %s%s\n" "$DIM" \
    "$(plist_read CFBundleShortVersionString "$PLIST")" \
    "$(plist_read CFBundleVersion "$PLIST")" "$APP_SIZE" "$RESET"
printf "  %s升级：先更新原版微信，再运行 ./update.sh%s\n\n" "$DIM" "$RESET"
