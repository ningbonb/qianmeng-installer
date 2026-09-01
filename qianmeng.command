#!/bin/bash
# 千梦一键入口 — macOS（Linux 下也可通过 bash 运行）。

QIANMENG_INSTALLER_VERSION="0.1.2"
STATE_DIR="$HOME/.qianmeng-installer"
LOG_FILE="$STATE_DIR/qianmeng.log"
REPO='ningbonb/qianmeng-installer'
BRAND_MARKER='# qianmeng-installer managed brand configuration'
LOGO_URL='https://sales.ws.126.net/minisite/2026/0901/1788255726_logo.png'

version_is_newer() {
  awk -v candidate="${1#v}" -v current="${2#v}" 'BEGIN {
    candidate_parts = split(candidate, candidate_values, ".")
    current_parts = split(current, current_values, ".")
    count = candidate_parts > current_parts ? candidate_parts : current_parts
    for (part = 1; part <= count; part++) {
      candidate_value = part <= candidate_parts ? candidate_values[part] + 0 : 0
      current_value = part <= current_parts ? current_values[part] + 0 : 0
      if (candidate_value > current_value) exit 0
      if (candidate_value < current_value) exit 1
    }
    exit 1
  }'
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

prompt_update() {
  local latest seen answer
  latest="$(cat "$STATE_DIR/latest_tag" 2>/dev/null)"
  seen="$(cat "$STATE_DIR/seen_tag" 2>/dev/null)"
  [ -n "$latest" ] && [ "$latest" != "$seen" ] || return 0
  version_is_newer "$latest" "$QIANMENG_INSTALLER_VERSION" || return 0
  echo "发现新版本：$latest（当前：v$QIANMENG_INSTALLER_VERSION）"
  printf '现在下载更新，并在下次启动时生效？[y/N] '
  read -r -t 5 answer
  if [ "$answer" = y ] || [ "$answer" = Y ]; then
    if curl -fsSL -m 30 -o "$HERE/qianmeng.command.new" "https://raw.githubusercontent.com/$REPO/$latest/qianmeng.command"; then
      echo '更新已下载，下次启动时生效。'
      return 0
    fi
    rm -f "$HERE/qianmeng.command.new"
    echo '更新下载失败，继续使用当前版本。'
    return 0
  fi
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$latest" > "$STATE_DIR/seen_tag"
}

check_update_in_background() {
  mkdir -p "$STATE_DIR"
  (
    local latest
    latest="$(curl -fsSL -m 5 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$latest" ] && printf '%s\n' "$latest" > "$STATE_DIR/latest_tag"
  ) >/dev/null 2>&1 &
}

prompt_dsh_update() {
  local current latest seen answer
  current="$(dsh --version 2>/dev/null | tr -d 'v')"
  latest="$(cat "$STATE_DIR/dsh_latest_version" 2>/dev/null)"
  seen="$(cat "$STATE_DIR/dsh_seen_version" 2>/dev/null)"
  [ -n "$current" ] && [ -n "$latest" ] && [ "$latest" != "$seen" ] || return 0
  version_is_newer "$latest" "$current" || return 0
  echo "DeepSeek Harness 有新版本：v$latest（当前：v$current）"
  printf '现在更新 DeepSeek Harness？[y/N] '
  read -r -t 5 answer
  if [ "$answer" = y ] || [ "$answer" = Y ]; then
    configure_npm_prefix || return 1
    echo '正在更新 DeepSeek Harness…'
    $NPM install -g @deepseek-ai/dsh@latest || return 1
    fix_path
    dsh_ok || return 1
    return 0
  fi
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$latest" > "$STATE_DIR/dsh_seen_version"
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
  local plugin="$1"
  if plugin_installed "$plugin"; then
    return 0
  fi
  echo "正在安装：$plugin"
  dsh plugin --profile web add "$plugin"
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
  ensure_plugin dsh-client-ui-brand || return 1
  ensure_plugin dsh-web-desktop || return 1
  configure_brand || return 1
  echo '千梦组件已就绪。'
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
  local choice
  echo ''
  echo '请选择使用方式：'
  echo '  [1] 浏览器 Web（默认）'
  echo '  [2] 千梦客户端'
  printf '输入编号 [1]: '
  read -r choice
  case "${choice:-1}" in
    2) launch_desktop ;;
    *) launch_web ;;
  esac
}

main() {
  HERE="$(cd "$(dirname "$0")" && pwd)"
  apply_pending_update
  prompt_update
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
    prompt_dsh_update || { echo 'DeepSeek Harness 更新失败。'; pause_then_exit; }
    check_dsh_update_in_background
  fi
  ensure_product_setup || { echo '千梦组件安装或配置失败。'; pause_then_exit; }
  choose_mode
}

main "$@"
