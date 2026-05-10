#!/usr/bin/env bash
# luo — shell command palette 一键安装/卸载脚本
# 安装: ./install.sh
# 卸载: ./install.sh --uninstall
# curl安装: curl -fsSL https://raw.githubusercontent.com/wuluoluoda/luo-command-palette/main/install.sh | bash
set -euo pipefail

GITHUB_RAW="https://raw.githubusercontent.com/wuluoluoda/luo-command-palette/main"

DEST="${LUO_HOME:-$HOME/.luo}"
MARK_BEGIN="# >>> luo script hub"
MARK_END="# <<< luo script hub"
ALIAS_MARK_BEGIN="# >>> luo aliases"
ALIAS_MARK_END="# <<< luo aliases"

_require_cmd() { command -v "$1" >/dev/null 2>&1; }

_uninstall() {
  echo "开始卸载 luo..."

  if [[ -d "$DEST" ]]; then
    rm -rf "$DEST"
    echo "✅ 已删除 $DEST"
  else
    echo "ℹ️  未找到安装目录 $DEST"
  fi

  local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
  if [[ -f "$zshrc" ]] && grep -qF "$MARK_BEGIN" "$zshrc" 2>/dev/null; then
    local tmp
    tmp=$(mktemp)
    sed -n "/${MARK_BEGIN}/,/ ${MARK_END}/p" "$zshrc" 2>/dev/null | grep -vF "$MARK_BEGIN" | grep -vF "$MARK_END" | grep -v "^$" >/dev/null || true
    awk "/${MARK_BEGIN}/,/${MARK_END}/{next} {print}" "$zshrc" > "$tmp" && mv "$tmp" "$zshrc"
    echo "✅ 已从 $zshrc 移除 luo 配置块"
  fi

  echo ""
  echo "✅ luo 已完全卸载"
  echo ""
  echo "请重新打开终端或执行: exec zsh"
  exit 0
}

if [[ "${1:-}" == "--uninstall" ]]; then
  _uninstall
fi

# curl | bash 时 BASH_SOURCE[0] 为空、"bash" 或 "-"
_is_remote() {
  local src="${BASH_SOURCE[0]:-}"
  [[ -z "$src" || "$src" == "bash" || "$src" == "-" ]]
}

# ── macOS 检查 ────────────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "luo 目前仅在 macOS 上测试过，继续安装请按 Enter，Ctrl+C 中止。" >&2
  read -r
fi

# ── fzf 检查 ─────────────────────────────────────────────────────────────────
if ! _require_cmd fzf; then
  echo ""
  echo "luo 依赖 fzf，当前环境未安装。"
  if _require_cmd brew; then
    read -rp "用 Homebrew 安装 fzf？[Y/n] " _yn
    _yn="${_yn:-Y}"
    if [[ "$_yn" =~ ^[Yy] ]]; then
      brew install fzf
    else
      echo "请先安装 fzf：brew install fzf" >&2
      exit 1
    fi
  else
    echo "未找到 Homebrew。请先安装 fzf 再重新运行：" >&2
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
    echo "  brew install fzf" >&2
    exit 1
  fi
fi

# ── 建目录 & 复制/下载文件 ───────────────────────────────────────────────────
mkdir -p "$DEST/scripts" "$DEST/alias-scripts"

if _is_remote; then
  # curl | bash 模式：从 GitHub 拉取源文件
  if ! _require_cmd curl; then
    echo "luo: 需要 curl，但未找到" >&2; exit 1
  fi
  echo "正在从 GitHub 下载 luo.zsh …"
  curl -fsSL "$GITHUB_RAW/luo.zsh"             -o "$DEST/luo.zsh"
  curl -fsSL "$GITHUB_RAW/registry.tsv.example" -o "$DEST/registry.tsv.example"
  if [[ ! -f "$DEST/registry.tsv" ]]; then
    cp "$DEST/registry.tsv.example" "$DEST/registry.tsv"
  fi
else
  # 本地克隆模式
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$ROOT/luo.zsh" "$DEST/luo.zsh"
  chmod a+r "$DEST/luo.zsh"
  if [[ ! -f "$DEST/registry.tsv" ]]; then
    cp "$ROOT/registry.tsv.example" "$DEST/registry.tsv"
    chmod a+r "$DEST/registry.tsv"
  fi
fi

# ── 写入 ~/.zshrc ────────────────────────────────────────────────────────────
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
[[ -f "$ZSHRC" ]] || touch "$ZSHRC"

if grep -qF "$MARK_BEGIN" "$ZSHRC" 2>/dev/null; then
  if grep -qF "$MARK_END" "$ZSHRC" 2>/dev/null; then
    if sed -n "/^${MARK_BEGIN}$/,/^${MARK_END}$/p" "$ZSHRC" | grep -qF "$ALIAS_MARK_BEGIN"; then
      echo "已检测到 ~/.zshrc 中的 luo 配置块，跳过写入。"
    else
      tmp=$(mktemp)
      awk -v end="$MARK_END" -v ab="$ALIAS_MARK_BEGIN" -v ae="$ALIAS_MARK_END" '
        $0 == end {
          print ab
          print ae
          print
          next
        }
        { print }
      ' "$ZSHRC" >"$tmp" && mv "$tmp" "$ZSHRC"
      echo "已检测到 ~/.zshrc 中的 luo 配置块，并补齐 aliases 区域。"
    fi
  else
    echo "⚠️  检测到 ~/.zshrc 中 luo 配置块起始标记，但缺少结束标记；为避免误改，请手动检查 $ZSHRC。" >&2
  fi
else
  {
    printf '\n%s\n' "$MARK_BEGIN"
    # 仅当用户指定了非默认路径时，才写 export LUO_HOME
    if [[ "$DEST" != "$HOME/.luo" ]]; then
      printf 'export LUO_HOME=%q\n' "$DEST"
    fi
    printf '[ -f %q ] && source %q\n' "$DEST/luo.zsh" "$DEST/luo.zsh"
    printf '%s\n' "$ALIAS_MARK_BEGIN"
    printf '%s\n' "$ALIAS_MARK_END"
    printf '%s\n' "$MARK_END"
  } >>"$ZSHRC"
  echo "已将 luo 写入: ${ZSHRC}（新开终端自动生效）"
fi

# ── 安装完成提示 ──────────────────────────────────────────────────────────────
cat <<EOF

✅  luo 已安装到 $DEST

▶  在当前终端立刻激活（或新开一个终端）：
     source "$DEST/luo.zsh"

▶  快速上手：
     luo add "caffeinate -di"    # 登记一条 shell 命令
     luo help                    # 查看 luo 子命令说明
     luo cmd                     # fzf 选已登记命令，回车后出现在命令行
     luo add ./你的脚本.sh       # 登记一个脚本

EOF
