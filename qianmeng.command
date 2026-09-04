#!/bin/bash
# 千梦一键入口 — macOS（Linux 下也可通过 bash 运行）。

QIANMENG_INSTALLER_VERSION="0.1.5"
STATE_DIR="$HOME/.qianmeng-installer"
LOG_FILE="$STATE_DIR/qianmeng.log"
REPO='ningbonb/qianmeng-installer'
BRAND_MARKER='# qianmeng-installer managed brand configuration'
LOGO_URL='https://sales.ws.126.net/minisite/2026/0901/1788255726_logo.png'
BRAND_PLUGIN_NAME='dsh-client-ui-brand'
BRAND_PLUGIN_SPEC='dsh-client-ui-brand@0.1.10'
DESKTOP_PLUGIN_NAME='dsh-web-desktop'
DESKTOP_PLUGIN_SPEC='dsh-web-desktop@0.1.2'

version_is_newer() {
  awk -v candidate="${1#v}" -v current="${2#v}" 'function compare_pre_release(candidate_pre, current_pre, candidate_values, current_values, candidate_count, current_count, part, candidate_value, current_value, candidate_numeric, current_numeric) {
    if (candidate_pre == "" && current_pre != "") return 1
    if (candidate_pre != "" && current_pre == "") return -1
    candidate_count = split(candidate_pre, candidate_values, ".")
    current_count = split(current_pre, current_values, ".")
    for (part = 1; part <= candidate_count || part <= current_count; part++) {
      if (part > candidate_count) return -1
      if (part > current_count) return 1
      candidate_value = candidate_values[part]
      current_value = current_values[part]
      candidate_numeric = candidate_value ~ /^[0-9]+$/
      current_numeric = current_value ~ /^[0-9]+$/
      if (candidate_numeric && current_numeric) {
        if (candidate_value + 0 > current_value + 0) return 1
        if (candidate_value + 0 < current_value + 0) return -1
      } else if (candidate_numeric != current_numeric) {
        return candidate_numeric ? -1 : 1
      } else {
        if (candidate_value > current_value) return 1
        if (candidate_value < current_value) return -1
      }
    }
    return 0
  } BEGIN {
    candidate_segment_count = split(candidate, candidate_segments, "-")
    current_segment_count = split(current, current_segments, "-")
    candidate_pre = candidate_segment_count > 1 ? substr(candidate, length(candidate_segments[1]) + 2) : ""
    current_pre = current_segment_count > 1 ? substr(current, length(current_segments[1]) + 2) : ""
    candidate_parts = split(candidate_segments[1], candidate_values, ".")
    current_parts = split(current_segments[1], current_values, ".")
    count = candidate_parts > current_parts ? candidate_parts : current_parts
    for (part = 1; part <= count; part++) {
      candidate_value = part <= candidate_parts ? candidate_values[part] + 0 : 0
      current_value = part <= current_parts ? current_values[part] + 0 : 0
      if (candidate_value > current_value) exit 0
      if (candidate_value < current_value) exit 1
    }
    exit compare_pre_release(candidate_pre, current_pre) > 0 ? 0 : 1
  }'
}

normalize_version() {
  printf '%s\n' "$1" | grep -Eo 'v?[0-9]+(\.[0-9]+){1,2}(-[0-9A-Za-z.-]+)?' | head -1 | sed 's/^v//'
}

apply_pending_update() {
  [ -f "$HERE/qianmeng.command.new" ] || return 0
  if [ -s "$HERE/qianmeng.command.new" ] && head -1 "$HERE/qianmeng.command.new" | grep -q '^#!'; then
    chmod +x "$HERE/qianmeng.command.new"
    mv -f "$HERE/qianmeng.command.new" "$HERE/qianmeng.command"
    exec "$HERE/qianmeng.command"
  fi
  rm -f "$HERE/qianmeng.command.new"
}

installer_update_available() {
  local latest latest_tag
  latest_tag="$(cat "$STATE_DIR/latest_tag" 2>/dev/null)"
  latest="$(normalize_version "$latest_tag")"
  [ -n "$latest" ] && version_is_newer "$latest" "$QIANMENG_INSTALLER_VERSION" || return 1
  AVAILABLE_INSTALLER_TAG="$latest_tag"
  AVAILABLE_INSTALLER_VERSION="$latest"
}

download_installer_update() {
  installer_update_available || return 1
  if curl -fsSL -m 30 -o "$HERE/qianmeng.command.new" "https://raw.githubusercontent.com/$REPO/$AVAILABLE_INSTALLER_TAG/qianmeng.command"; then
    echo '千梦更新已下载，正在重新启动。'
    apply_pending_update
  fi
  rm -f "$HERE/qianmeng.command.new"
  echo '千梦更新下载失败，请稍后重试。'
  return 1
}

check_update_in_background() {
  mkdir -p "$STATE_DIR"
  (
    local latest
    latest="$(curl -fsSL -m 5 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$latest" ] && printf '%s\n' "$latest" > "$STATE_DIR/latest_tag"
  ) >/dev/null 2>&1 &
}

dsh_update_available() {
  local current latest latest_value
  current="$(normalize_version "$(dsh --version 2>/dev/null)")"
  latest_value="$(cat "$STATE_DIR/dsh_latest_version" 2>/dev/null)"
  latest="$(normalize_version "$latest_value")"
  [ -n "$current" ] && [ -n "$latest" ] && version_is_newer "$latest" "$current" || return 1
  AVAILABLE_DSH_CURRENT="$current"
  AVAILABLE_DSH_VERSION="$latest"
}

update_dsh() {
  dsh_update_available || return 1
  configure_npm_prefix || return 1
  echo "正在更新 DeepSeek Harness：v${AVAILABLE_DSH_CURRENT} → v${AVAILABLE_DSH_VERSION}…"
  $NPM install -g @deepseek-ai/dsh@latest || return 1
  fix_path
  dsh_ok
}

check_dsh_update_in_background() {
  dsh_ok || return 0
  mkdir -p "$STATE_DIR"
  (
    local latest
    latest="$(npm view @deepseek-ai/dsh version --silent 2>/dev/null | head -1)"
    [ -n "$latest" ] && printf '%s\n' "$latest" > "$STATE_DIR/dsh_latest_version"
  ) >/dev/null 2>&1 &
}

fix_path() {
  export PATH="$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
  for directory in "$HOME"/.nvm/versions/node/*/bin; do
    [ -d "$directory" ] && PATH="$directory:$PATH"
  done
}

pause_then_exit() {
  printf '按回车退出'
  read -r _
  exit 1
}

node_version_ok() {
  local version major minor
  version="$(node -v 2>/dev/null | tr -d 'v')"
  [ -n "$version" ] || return 1
  major="${version%%.*}"
  minor="${version#*.}"; minor="${minor%%.*}"
  case "$major" in ''|*[!0-9]*) return 1 ;; esac
  case "$minor" in ''|*[!0-9]*) minor=0 ;; esac
  [ "$major" -ge 24 ] || { [ "$major" -eq 22 ] && [ "$minor" -ge 19 ]; }
}

install_node() {
  if command -v brew >/dev/null 2>&1; then
    echo '正在通过 Homebrew 安装 Node.js…'
    brew install node || return 1
    fix_path
    return 0
  fi
  echo '请从 https://nodejs.org 安装 Node.js 后重新运行。'
  return 1
}

dsh_ok() {
  command -v dsh >/dev/null 2>&1 && dsh --version >/dev/null 2>&1
}

configure_npm_prefix() {
  local npm_root choice
  npm_root="$(npm root -g 2>/dev/null)"
  if [ -n "$npm_root" ] && [ -d "$npm_root" ] && [ -w "$npm_root" ]; then
    NPM='npm'
    return 0
  fi
  echo 'npm 全局目录不可写。'
  echo '  [1] 使用 sudo（需要密码）'
  echo '  [2] 使用用户目录 ~/.npm-global（默认）'
  printf '输入编号 [2]: '
  read -r choice
  if [ "${choice:-2}" = '1' ]; then
    NPM='sudo npm'
    return 0
  fi
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global" || return 1
  export PATH="$HOME/.npm-global/bin:$PATH"
  NPM='npm'
}

profile_dir() {
  printf '%s/profiles/web\n' "${DSH_HOME:-$HOME/.dsh}"
}

plugin_installed() {
  local profile
  profile="$(profile_dir)"
  [ -f "$profile/package.json" ] && grep -q "\"$1\"" "$profile/package.json"
}

ensure_plugin() {
  local plugin="$1" spec="$2"
  if [ "$RECONCILE_COMPONENTS" != '1' ] && plugin_installed "$plugin"; then
    return 0
  fi
  echo "正在安装或更新：$spec"
  dsh plugin --profile web add "$spec"
}

configure_brand() {
  local profile patch
  profile="$(profile_dir)"
  patch="$profile/cordis.patch.yml"
  mkdir -p "$profile"
  [ -f "$patch" ] || : > "$patch"
  if [ "$(head -1 "$patch")" = '[]' ]; then
    tail -n +2 "$patch" > "$patch.new" && mv -f "$patch.new" "$patch"
  fi
  grep -q "^$BRAND_MARKER$" "$patch" && return 0
  cat >> "$patch" <<EOF

$BRAND_MARKER
- id: dsh-client-ui-brand
  config:
    productName: 千梦
    logoUrl: $LOGO_URL
    logoAlt: 千梦 logo
EOF
}

ensure_product_setup() {
  local components_file components_version installed_components
  components_file="$STATE_DIR/components_version"
  components_version="$BRAND_PLUGIN_SPEC|$DESKTOP_PLUGIN_SPEC"
  installed_components="$(cat "$components_file" 2>/dev/null)"
  RECONCILE_COMPONENTS=0
  [ "$installed_components" = "$components_version" ] || RECONCILE_COMPONENTS=1
  ensure_plugin "$BRAND_PLUGIN_NAME" "$BRAND_PLUGIN_SPEC" || return 1
  ensure_plugin "$DESKTOP_PLUGIN_NAME" "$DESKTOP_PLUGIN_SPEC" || return 1
  configure_brand || return 1
  if [ "$RECONCILE_COMPONENTS" = '1' ]; then
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$components_version" > "$components_file"
  fi
}

port_pids() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null
}

open_url() {
  if command -v open >/dev/null 2>&1; then
    open "$1" 2>/dev/null || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$1" 2>/dev/null || true
  else
    echo "$1"
  fi
}

launch_web() {
  local port="${DSH_WEB_PORT:-3080}" pids pid choice status
  pids="$(port_pids "$port")"
  if [ -n "$pids" ]; then
    echo "端口已被占用：127.0.0.1:$port"
    echo '  [1] 结束旧进程并重启（默认）'
    echo '  [2] 直接打开已运行的页面'
    echo '  [3] 返回'
    printf '输入编号 [1]: '
    read -r choice
    case "${choice:-1}" in
      2) open_url "http://127.0.0.1:$port"; return 0 ;;
      3) return 0 ;;
      *)
        for pid in $pids; do kill "$pid" 2>/dev/null || true; done
        sleep 1
        ;;
    esac
  fi
  mkdir -p "$STATE_DIR"
  echo "==== $(date '+%F %T') web launch ====" >> "$LOG_FILE"
  dsh web 2>&1 | tee -a "$LOG_FILE"
  status=${PIPESTATUS[0]}
  [ "$status" -eq 0 ] || echo "启动失败，日志：$LOG_FILE"
  return "$status"
}

launch_desktop() {
  local notice_file="$STATE_DIR/desktop_first_use" status
  mkdir -p "$STATE_DIR"
  if [ ! -f "$notice_file" ]; then
    echo '首次启动客户端可能需要下载 Electron，请耐心等待；后续启动不会重复下载。'
    : > "$notice_file"
  fi
  echo "==== $(date '+%F %T') desktop launch ====" >> "$LOG_FILE"
  dsh plugin --profile web exec dsh-web-desktop -- --port 0 2>&1 | tee -a "$LOG_FILE"
  status=${PIPESTATUS[0]}
  [ "$status" -eq 0 ] || echo "启动失败，日志：$LOG_FILE"
  return "$status"
}

choose_mode() {
  local choice installer_option dsh_option next_option
  next_option=3
  installer_option=''
  dsh_option=''
  if dsh_update_available; then
    dsh_option=$next_option
    next_option=$((next_option + 1))
  fi
  if installer_update_available; then
    installer_option=$next_option
  fi
  echo ''
  echo '千梦已准备好，请选择操作：'
  echo '  [1] 通过浏览器打开'
  echo '  [2] 通过客户端打开'
  [ -n "$dsh_option" ] && echo "  [$dsh_option] 更新 DeepSeek Harness（v${AVAILABLE_DSH_CURRENT} → v${AVAILABLE_DSH_VERSION}）"
  [ -n "$installer_option" ] && echo "  [$installer_option] 更新千梦（v${QIANMENG_INSTALLER_VERSION} → v${AVAILABLE_INSTALLER_VERSION}）"
  printf '输入编号：'
  read -r choice
  case "${choice:-1}" in
    2) launch_desktop ;;
    1) launch_web ;;
    *)
      if [ "$choice" = "$dsh_option" ]; then
        update_dsh || { echo 'DeepSeek Harness 更新失败，请稍后重试。'; }
        choose_mode
      elif [ "$choice" = "$installer_option" ]; then
        download_installer_update || true
        choose_mode
      else
        echo '输入无效，请重新选择。'
        choose_mode
      fi
      ;;
  esac
}

main() {
  HERE="$(cd "$(dirname "$0")" && pwd)"
  apply_pending_update
  check_update_in_background
  fix_path
  if ! dsh_ok; then
    echo '未找到 dsh（或不可用），开始安装千梦所需组件。'
    if ! node_version_ok; then
      echo '检查 Node.js…'
      install_node || pause_then_exit
    fi
    node_version_ok || { echo 'Node.js 版本需要 22.19+ 或 24+。'; pause_then_exit; }
    configure_npm_prefix || pause_then_exit
    echo '安装 pnpm…'
    $NPM install -g pnpm || pause_then_exit
    echo '安装 dsh…'
    $NPM install -g @deepseek-ai/dsh || pause_then_exit
    fix_path
    dsh_ok || { echo 'dsh 安装后仍不可用。'; pause_then_exit; }
  else
    check_dsh_update_in_background
  fi
  ensure_product_setup || { echo '千梦组件安装或配置失败。'; pause_then_exit; }
  choose_mode
}

main "$@"
