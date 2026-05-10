# CmdRoster (luo) — command-line & script hub for zsh
# Usage: add to ~/.zshrc
#   source "${LUO_HOME:-$HOME/.luo}/luo.zsh"
#
# Registry: $LUO_HOME/registry.tsv — tab-separated, UTF-8:
#   name	description	kind	payload
# kind: file → payload 为相对 LUO_HOME 的路径（如 scripts/foo.sh）
# kind: shell → payload 为整段 shell 命令（由 luo cmd 选入后记入 zsh 历史再调出；新写入会转义 Tab/换行）

_luo_home() {
  print -r -- "${LUO_HOME:-$HOME/.luo}"
}

_luo_registry() {
  print -r -- "$(_luo_home)/registry.tsv"
}

_luo_header_new() {
  print -r $'name\tdescription\tkind\tpayload'
}

_luo_tsv_escape() {
  local s=$1
  if [[ $s != __luo_esc1__:* && $s != *'\'* && $s != *$'\t'* && $s != *$'\r'* && $s != *$'\n'* ]]; then
    print -r -- "$s"
    return 0
  fi
  s=${s//\\/\\\\}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  s=${s//$'\n'/\\n}
  print -r -- "__luo_esc1__:$s"
}

_luo_tsv_unescape() {
  local s=$1 out= ch next
  integer i len
  [[ $s == __luo_esc1__:* ]] || { print -r -- "$s"; return 0; }
  s=${s#__luo_esc1__:}
  len=${#s}
  for (( i = 1; i <= len; i++ )); do
    ch=${s[i]}
    if [[ $ch == '\' && $i -lt $len ]]; then
      i=$(( i + 1 ))
      next=${s[i]}
      case $next in
        n) out+=$'\n' ;;
        r) out+=$'\r' ;;
        t) out+=$'\t' ;;
        '\') out+='\' ;;
        *) out+="\\$next" ;;
      esac
    else
      out+=$ch
    fi
  done
  print -r -- "$out"
}

_luo_registry_line() {
  print -r -- "$(_luo_tsv_escape "$1")"$'\t'"$(_luo_tsv_escape "$2")"$'\t'"$(_luo_tsv_escape "$3")"$'\t'"$(_luo_tsv_escape "$4")"
}

_luo_parse_registry_line() {
  local line=$1 norm
  local -a parts
  typeset -ga _LUO_ROW
  _LUO_ROW=()
  norm=$(_luo_normalize_body_line "$line") || return 1
  IFS=$'\t' read -rA parts <<<"$norm"
  (( ${#parts[@]} >= 4 )) || return 1
  _LUO_ROW=(
    "$(_luo_tsv_unescape "$parts[1]")"
    "$(_luo_tsv_unescape "$parts[2]")"
    "$(_luo_tsv_unescape "$parts[3]")"
    "$(_luo_tsv_unescape "$parts[4]")"
  )
  return 0
}

# 将正文行规范为四列；支持旧三列（视为 kind=file, payload=原第三列）
_luo_normalize_body_line() {
  local line=$1
  local -a parts
  line=${line%%$'\r'}
  while [[ $line == [[:space:]]* ]]; do
    line=${line#[[:space:]]}
  done
  while [[ $line == *[[:space:]] ]]; do
    line=${line%[[:space:]]}
  done
  [[ -n $line ]] || return 1
  IFS=$'\t' read -rA parts <<<"$line"
  [[ $parts[1] == name ]] && return 1
  if (( ${#parts[@]} < 3 )); then
    print -u2 "luo: 跳过列数不足的 registry 行（${#parts[@]} 段）: ${(V)line}"
    return 1
  fi
  if (( ${#parts[@]} == 3 )); then
    print -r -- "$parts[1]"$'\t'"$parts[2]"$'\t'"file"$'\t'"$parts[3]"
  elif (( ${#parts[@]} == 4 )); then
    print -r -- "$parts[1]"$'\t'"$parts[2]"$'\t'"$parts[3]"$'\t'"$parts[4]"
  elif (( ${#parts[@]} > 4 )); then
    print -r -- "$parts[1]"$'\t'"$parts[2]"$'\t'"$parts[3]"$'\t'"${(pj:\t:)parts[4,-1]}"
  else
    print -u2 "luo: 跳过列数异常的 registry 行（期望 >=3 列，实际 ${#parts[@]} 段）: ${line[1,60]}…"
    return 1
  fi
}

# 若仍为旧表头（含 rel_path、无 kind），整表迁移为四列
_luo_migrate_registry_if_needed() {
  local r first tmp line norm
  r=$(_luo_registry)
  [[ -f $r ]] || return 0
  IFS= read -r first <"$r"
  [[ $first == *rel_path* ]] || return 0
  [[ $first == *$'\t'kind$'\t'* ]] && return 0
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-migrate.XXXXXX")
  _luo_header_new >"$tmp"
  tail -n +2 "$r" | while IFS= read -r line; do
    [[ -z $line ]] && continue
    [[ $line == name$'\t'* ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    print -r -- "$norm"
  done >>"$tmp"
  command mv -f "$tmp" "$r"
  print -u2 "luo: 已将 registry.tsv 迁移为四列格式（name/description/kind/payload）"
}

_luo_init_files() {
  local h r u
  h=$(_luo_home)
  r="$h/registry.tsv"
  u="$h/usage.tsv"
  mkdir -p "$h/scripts" "$h/alias-scripts"
  if [[ ! -f $r ]]; then
    _luo_header_new >"$r"
  else
    _luo_migrate_registry_if_needed
  fi
  if [[ ! -f $u ]]; then
    print -r $'name\tcount' >"$u"
  fi
}

_luo_usage_file() {
  print -r -- "$(_luo_home)/usage.tsv"
}

# 返回整数次（无记录为 0）
_luo_usage_get() {
  local name=$1 f r
  f=$(_luo_usage_file)
  [[ -f $f ]] || { print -r 0; return 0 }
  r=$(command awk -F '\t' -v n="$name" 'NR>1 && $1==n { print $2; exit }' "$f")
  [[ -n $r && $r == <-> ]] || r=0
  print -r -- "$r"
}

_luo_usage_incr() {
  local name=$1 f tmp
  [[ -n $name ]] || return 0
  f=$(_luo_usage_file)
  _luo_init_files
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-usage.XXXXXX")
  command awk -F '\t' -v OFS='\t' -v n="$name" '
    NR==1 { print; next }
    $1 == n {
      c = $2 + 0
      if (c < 0) c = 0
      c++
      print $1, c
      found = 1
      next
    }
    { print }
    END {
      if (!found) print n "\t" 1
    }
  ' "$f" >"$tmp" || return 1
  command mv -f "$tmp" "$f"
}

_luo_usage_remove_name() {
  local name=$1 f tmp
  f=$(_luo_usage_file)
  [[ -f $f ]] || return 0
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-usage.XXXXXX")
  command awk -F '\t' -v n="$name" 'NR==1{print;next} $1!=n{print}' "$f" >"$tmp" || return 1
  command mv -f "$tmp" "$f"
}

_luo_alias_file() {
  print -r -- "$(_luo_home)/alias"
}

# 读取 alias 文件并定义（或撤销）快捷函数；source 时与 luo alias 变更后均调用
_luo_alias_load() {
  local f name
  f=$(_luo_alias_file)
  # 先撤销上一次设置的快捷函数（避免改名后旧函数残留）
  # 注意：若曾错误执行 luo alias luo，全局变量可能仍为 luo；此时绝不能 unfunction luo，
  # 否则会删掉本文件刚定义的主入口 luo()（source 末尾顺序：先定义 luo，再调本函数）。
  if [[ -n ${_LUO_CURRENT_ALIAS:-} ]]; then
    if [[ ${_LUO_CURRENT_ALIAS} != luo ]]; then
      unfunction "${_LUO_CURRENT_ALIAS}" 2>/dev/null || :
    fi
    unset _LUO_CURRENT_ALIAS
  fi
  [[ -f $f ]] || return 0
  IFS= read -r name <"$f"
  name=${name//[[:space:]]/}
  [[ -n $name ]] || return 0
  # 旧版本曾允许 luo，会导致覆盖本文件定义的 luo 并 FUNCNEST；发现则自愈
  if [[ $name == luo ]]; then
    print -u2 "luo: ~/.luo/alias 中非法快捷名 'luo' 已忽略，并删除该文件（请改用 luo alias <其他名>）。"
    command rm -f "$f"
    return 0
  fi
  # 定义同名 zsh 函数，打开 fzf 选择器（与 luo cmd 同义）
  eval "${name}() { luo cmd \"\$@\"; }"
  typeset -g _LUO_CURRENT_ALIAS=$name
}

_luo_alias_cmd() {
  local name=${1:-} f
  f=$(_luo_alias_file)
  _luo_init_files

  # 无参数：显示当前状态
  if [[ -z $name ]]; then
    if [[ -n ${_LUO_CURRENT_ALIAS:-} ]]; then
      print -r -- "当前快捷命令: ${_LUO_CURRENT_ALIAS}  （等同于 luo cmd）"
    else
      print -r -- "未设置快捷命令。用法: luo alias <命令名>  例: luo alias pp"
    fi
    return 0
  fi

  # 取消
  if [[ $name == off || $name == - || $name == --unset ]]; then
    if [[ -n ${_LUO_CURRENT_ALIAS:-} ]]; then
      local old=$_LUO_CURRENT_ALIAS
      unfunction "$old" 2>/dev/null || :
      unset _LUO_CURRENT_ALIAS
      command rm -f "$f"
      print -r -- "luo: 已取消快捷命令 '${old}'。"
    else
      command rm -f "$f"
      print -r -- "luo: 没有设置过快捷命令。"
    fi
    return 0
  fi

  # 基本格式校验
  if [[ $name == *[[:space:]]* || $name == */* || $name == -* ]]; then
    print -u2 "luo alias: 命令名不能含空格、斜杠或以 - 开头: $name"
    return 1
  fi

  # 禁止与主入口同名：否则会 eval 出 luo(){ luo cmd … } 覆盖本函数，导致 FUNCNEST 无限递归
  if [[ $name == luo ]]; then
    print -u2 "luo alias: 不能使用 'luo' 作为快捷名（会与主命令递归冲突）。请换其他短名，例如: luo alias pp"
    return 1
  fi

  # 与系统命令冲突时警告
  if command -v "$name" >/dev/null 2>&1; then
    print -u2 "luo alias: 警告：'$name' 已是系统中存在的命令。"
    if [[ -t 0 ]]; then
      read -q "?仍要覆盖？[y/N] " || { print ""; return 1; }
      print ""
    else
      print -u2 "luo alias: 非交互终端，跳过覆盖。"
      return 1
    fi
  fi

  print -r -- "$name" >"$f"
  _luo_alias_load
  print -r -- "luo: 快捷命令已设为 '${name}'（新终端自动生效，当前终端已即时生效）。"
}

_luo_require_fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    print -u2 "luo: 需要安装 fzf（例如: brew install fzf）"
    return 127
  fi
}

_luo_usage() {
  print -r -- "luo 子命令总览（与常见 CLI 一致：luo help = 本说明；打开已登记条目用 luo cmd）:

  打印本页 — 本工具有哪些子命令（含 list / alias / add …）:
    luo help          推荐（与 --help 语义一致）
    luo usage / luo commands / luo -h / --help  同上
    luo               无参数时默认打印本页

  打开已登记 shell / 脚本的 fzf 选择器（名称字母序；Tab 用当前项名称缩小搜索；Enter 填回命令行）:
    luo cmd           主入口（旧版曾用 luo help 表示此功能，现已拆分）
    luo pick          与 luo cmd 完全同义（保留兼容）
                    普通模式下按 Ctrl+A 会临时查询当前 zsh aliases，
                    并尽量用第一个匹配 alias 形式填回命令行；
                    例如 alias gs='git status' 时，选中 git status -sb 后会填入 gs -sb。
                    若未找到匹配 alias，会进入创建 alias 提示；创建后写入 ~/.zshrc 的 luo aliases 区域，
                    创建或取消后返回本选择器。
                    按 Fn+F2（笔记本常见：须 Fn 才发出 F2）进入/退出「删除模式」（界面为绿色）；删除模式下 Enter 直接删当前项。
                    每次在普通模式下用 Enter 将命令填入命令行，并累计使用次数（见 usage.tsv）；
                    删除前若次数 >30 会交互确认（非交互终端则拒绝删除）。
  luo list          按名字母序列出（同样会先补全）
  luo add [选项] <一段文本…>  导入一条入口（见下方判定规则）
                    多行粘贴：luo add 后直接粘贴，按 Ctrl-D 保存（默认按首个命令片段命名）
                    也可把第一行接在 add 后面：luo add cd app，继续粘贴后续行，按 Ctrl-D 保存
                    管道/剪贴板：pbpaste | luo add -  （单独的 - 表示从标准输入读取）
  luo sync [-p]     扫描 scripts/ 补全缺失；-p 删除失效 file 表项
  luo rm / remove   直接进入 luo cmd 且初始为删除模式（不接受其它参数）
  luo alias [名字]  设置「luo cmd / pick」的快捷命令（如 pp）；luo alias 查看；luo alias off 取消
  luo home          打印 LUO_HOME

命令行补全（zsh）：输入 luo <Tab> 可补全子命令。~/.zshrc 须先 compinit 再 source 本文件；见文件末尾 precmd 兜底注册。

luo add 判定（剩余参数会拼成一段字符串，外层引号会剥掉一层）:
  · 若看起来像「脚本路径」且磁盘上存在该普通文件 → kind=file：在 scripts/ 建符号链接并登记
    条件：路径含 \"/\"，或以 \"./\" \"../\" 开头，且 [[ -f 解析后路径 ]]
  · 否则 → kind=shell：整段字符串作为命令（由 luo cmd 选入后记入历史再调出），不建链接
    支持真实多行命令：执行 luo add 后粘贴多行命令，按 Ctrl-D 保存；
    若第一行写成 luo add cd app，会继续读取后续行直到 Ctrl-D，合并到同一条命令；
    也可用单独参数 - 从标准输入读入：pbpaste | luo add -

  无 \"/\" 的相对脚本请写成 ./foo.sh 再 luo add。

选项:
  -n <名称>   列表里显示的名字（脚本默认 basename；命令默认取首个命令片段，重名自动加 -2）
  -d <简介>   列表简介；file 且省略时读 \"# luo:desc ...\"
  -f          覆盖同名；shell 时若已有相同命令也会直接删掉旧条目再登记"
}

_luo_registry_sorted_fourcol_lines() {
  local r line norm
  r=$(_luo_registry)
  tail -n +2 "$r" 2>/dev/null | command grep -v '^[[:space:]]*$' | while IFS= read -r line; do
    [[ -z $line ]] && continue
    [[ $line == name$'\t'* ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    print -r -- "$norm"
  done | LC_ALL=C sort -f -t $'\t' -k1,1
}

_luo_list() {
  _luo_init_files
  _luo_sync_merge ""
  _luo_header_new
  _luo_registry_sorted_fourcol_lines
}

# 按首列名字判断是否存在
_luo_name_in_registry() {
  local want=$1 r line
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    _luo_parse_registry_line "$line" || continue
    [[ $_LUO_ROW[1] == "$want" ]] && return 0
  done < <(tail -n +2 "$r" 2>/dev/null)
  return 1
}

_luo_desc_from_script() {
  local src=$1 line raw
  [[ -f $src ]] || return 1
  while IFS= read -r line; do
    [[ $line == '# luo:desc'* ]] || continue
    raw=${line#\# luo:desc}
    while [[ $raw == [[:space:]]* ]]; do
      raw=${raw#[[:space:]]}
    done
    raw=${raw%%$'\r'}
    [[ -n $raw ]] || return 1
    print -r -- "$raw"
    return 0
  done <"$src"
  return 1
}

_luo_desc_one_line() {
  local s=$1
  s=${s//$'\t'/ }
  s=${s//$'\r'/ }
  s=${s//$'\n'/ ; }
  print -r -- "$s"
}

_luo_remove_registry_row_by_name() {
  local name=$1 r tmp line
  r=$(_luo_registry)
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-registry.XXXXXX")
  _luo_header_new >"$tmp"
  tail -n +2 "$r" 2>/dev/null | while IFS= read -r line; do
    [[ -z $line ]] && continue
    _luo_parse_registry_line "$line" || continue
    [[ $_LUO_ROW[1] == "$name" ]] && continue
    print -r -- "$line" >>"$tmp"
  done
  command mv -f "$tmp" "$r"
}

# 打印一行 kind<TAB>payload，供按名称删除使用
_luo_row_kind_payload_for_name() {
  local want=$1 r line
  typeset -g _LUO_ROW_KIND="" _LUO_ROW_PAYLOAD=""
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    _luo_parse_registry_line "$line" || continue
    [[ $_LUO_ROW[1] == "$want" ]] || continue
    _LUO_ROW_KIND=$_LUO_ROW[3]
    _LUO_ROW_PAYLOAD=$_LUO_ROW[4]
    return 0
  done < <(tail -n +2 "$r" 2>/dev/null)
  return 1
}

_luo_remove_by_name() {
  local name=$1 h kind payload
  [[ -n $name ]] || { print -u2 "luo: 名称不能为空"; return 1 }
  [[ $name == */* ]] && { print -u2 "luo: 名称不得包含路径分隔符"; return 1 }

  h=$(_luo_home)
  _luo_init_files
  if ! _luo_name_in_registry "$name"; then
    print -u2 "luo: 未找到名称: $name"
    return 1
  fi

  _luo_row_kind_payload_for_name "$name" || {
    print -u2 "luo: 无法解析条目: $name"
    return 1
  }
  kind=$_LUO_ROW_KIND
  payload=$_LUO_ROW_PAYLOAD

  if [[ $kind == file ]]; then
    if [[ $payload == scripts/* ]]; then
      if [[ -L "$h/$payload" || -e "$h/$payload" ]]; then
        command rm -f "$h/$payload"
        print -r -- "已删除 scripts 链接: $h/$payload"
      fi
    fi
  elif [[ $kind != shell ]]; then
    print -u2 "luo: 未知 kind: $kind"
    return 1
  fi

  _luo_remove_registry_row_by_name "$name" || return 1
  print -r -- "已从 registry 移除: $name"
}

# file 且 payload 为给定路径（如 scripts/foo）
_luo_registry_has_file_payload() {
  local want=$1 r line
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    _luo_parse_registry_line "$line" || continue
    [[ $_LUO_ROW[3] == file && $_LUO_ROW[4] == "$want" ]] && return 0
  done < <(tail -n +2 "$r" 2>/dev/null)
  return 1
}

_luo_sync_merge() {
  local verbose=$1 h scr r f rel desc added
  h=$(_luo_home)
  scr="$h/scripts"
  r=$(_luo_registry)
  _luo_init_files
  added=0
  for f in "$scr"/*(N); do
    [[ -e $f ]] || continue
    [[ -L $f ]] && [[ ! -e ${f:A} ]] && continue
    [[ -d ${f:A} ]] && continue
    rel="scripts/${f:t}"
    if _luo_registry_has_file_payload "$rel"; then
      continue
    fi
    desc=$(_luo_desc_from_script "${f:A}")
    [[ -z $desc ]] && desc="no description"
    desc=$(_luo_desc_one_line "$desc")
    _luo_registry_line "${f:t}" "$desc" "file" "$rel" >>"$r"
    [[ -n $verbose ]] && print -r -- "sync: 已登记 $rel"
    added=$((added + 1))
  done
  [[ -n $verbose && $added -eq 0 ]] && print -r -- "sync: 无新条目（scripts/ 均已在 registry 中）"
  return 0
}

_luo_sync_prune() {
  local h r tmp line norm n k p
  h=$(_luo_home)
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-prune.XXXXXX")
  _luo_header_new >"$tmp"
  tail -n +2 "$r" | while IFS= read -r line; do
    [[ -z $line ]] && continue
    norm=$(_luo_normalize_body_line "$line") || continue
    _luo_parse_registry_line "$line" || continue
    n=$_LUO_ROW[1]
    k=$_LUO_ROW[3]
    p=$_LUO_ROW[4]
    if [[ $k == file && $p == scripts/* && ! -e "$h/$p" ]]; then
      print -u2 "sync -p: 已移除失效条目: $n ($p)"
      continue
    fi
    print -r -- "$norm" >>"$tmp"
  done
  command mv -f "$tmp" "$r"
}

_luo_sync() {
  local prune=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p) prune=1; shift ;;
      -*)
        print -u2 "luo sync: 未知选项: $1"
        return 1
        ;;
      *) break ;;
    esac
  done
  [[ $# -gt 0 ]] && { print -u2 "luo sync: 不需要额外参数"; return 1 }
  _luo_init_files
  _luo_sync_merge 1
  [[ $prune -eq 1 ]] && _luo_sync_prune
}

# 从 shell 命令取默认 registry 名（取首个命令片段，保留安全字符）
_luo_default_name_from_shell() {
  local c=$1 line w part
  local -a lines z picked
  c=${c## #}
  c=${c%% #}
  lines=("${(@f)c}")
  line=${lines[1]}
  z=(${(z)line})
  if [[ ${z[1]} == cd && -n ${z[2]} ]]; then
    picked=("${z[1]}" "${z[2]:t}")
  elif [[ ${z[1]} == npm && ${z[2]} == run && -n ${z[3]} ]]; then
    picked=("${z[1]}" "${z[3]}")
  elif (( ${#z[@]} >= 2 )); then
    picked=("${z[1]}" "${z[2]}")
  else
    picked=("${z[1]}")
  fi
  for part in $picked; do
    part=${part//[^A-Za-z0-9_.-]/_}
    part=${part##_}
    part=${part%%_}
    [[ -n $part ]] && w+="${w:+-}$part"
  done
  [[ -z $w ]] && w="shell"
  if (( ${#w} > 24 )); then
    w=${w[1,24]}
    w=${w%-}
    w=${w%_}
    w=${w%.}
    [[ -z $w ]] && w="shell"
  fi
  print -r -- "$w"
}

_luo_unique_default_name() {
  local base=$1 name i
  name=$base
  i=2
  while _luo_name_in_registry "$name"; do
    name="${base}-${i}"
    i=$(( i + 1 ))
  done
  print -r -- "$name"
}

# 用于判断「是否为同一条 shell 命令」（去首尾空白、Tab，按 shell 词法压成空格序列）
_luo_shell_payload_key() {
  local s=$1
  s=${s//$'\t'/ }
  while [[ $s == [[:space:]]* ]]; do
    s=${s#[[:space:]]}
  done
  while [[ $s == *[[:space:]] ]]; do
    s=${s%[[:space:]]}
  done
  [[ -n $s ]] || return 1
  if [[ $s == *$'\n'* || $s == *$'\r'* ]]; then
    print -r -- "multiline:$s"
    return 0
  fi
  print -r -- "${(j: :)${(z)s}}"
}

# 打印所有与 payload 等价的 shell 登记名（每行一个，已排序去重）
_luo_matching_shell_names_for_payload_key() {
  local payload=$1 r line n k p want key
  want=$(_luo_shell_payload_key "$payload") || return 1
  r=$(_luo_registry)
  [[ -f $r ]] || return 1
  {
    while IFS= read -r line; do
      [[ -z $line ]] && continue
      _luo_parse_registry_line "$line" || continue
      n=$_LUO_ROW[1]
      k=$_LUO_ROW[3]
      p=$_LUO_ROW[4]
      [[ $k == shell ]] || continue
      key=$(_luo_shell_payload_key "$p") || continue
      [[ $key == "$want" ]] || continue
      print -r -- "$n"
    done < <(tail -n +2 "$r" 2>/dev/null)
  } | LC_ALL=C sort -u
}

# 是否为「脚本路径」：含 / 或以 ./ ../ 开头，且解析后为普通文件
_luo_arg_is_script_path() {
  local raw=$1 p
  p=$raw
  [[ $p == \~/* ]] && p="${HOME}/${p#\~/}"
  [[ $p == \~ ]] && p=$HOME
  [[ $p == */* || $p == ./* || $p == ../* ]] || return 1
  [[ -f ${p:A} ]] || return 1
  return 0
}

_luo_read_payload_from_stdin() {
  local prompt=${1:-"luo add: 请粘贴多行命令，结束后按 Ctrl-D："}
  local line
  local -a lines
  if [[ -t 0 ]]; then
    print -u2 "$prompt"
  fi
  while IFS= read -r line || [[ -n $line ]]; do
    lines+=("$line")
  done
  print -r -- "${(pj:\n:)lines}"
}

_luo_read_queued_paste_lines() {
  local line
  local -a lines
  [[ -t 0 ]] || return 0
  while IFS= read -r -t 0.08 line; do
    lines+=("$line")
  done
  (( ${#lines[@]} > 0 )) || return 0
  print -r -- "${(pj:\n:)lines}"
}

_luo_add() {
  local force=0 dest_name= desc= raw p src_abs h dest relpath r name kind payload
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f) force=1; shift ;;
      -n)
        [[ $# -ge 2 ]] || { print -u2 "luo add: -n 需要参数"; return 1 }
        dest_name=$2
        shift 2
        ;;
      -d)
        [[ $# -ge 2 ]] || { print -u2 "luo add: -d 需要参数"; return 1 }
        desc=$2
        shift 2
        ;;
      -)
        break
        ;;
      -*)
        print -u2 "luo add: 未知选项: $1"
        return 1
        ;;
      *) break ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    raw=$(_luo_read_payload_from_stdin)
  elif [[ $# -eq 1 && $1 == - ]]; then
    raw=$(_luo_read_payload_from_stdin)
  else
    raw="${(j: :)@}"
    if [[ -t 0 && $# -gt 1 ]]; then
      local continuation
      continuation=$(_luo_read_payload_from_stdin "luo add: 若还有后续行请继续粘贴，结束后按 Ctrl-D 保存：")
      if [[ -n $continuation ]]; then
        raw+=$'\n'"$continuation"
      fi
    fi
  fi
  raw=${raw## #}
  raw=${raw%% #}
  if [[ $raw == \"*\" ]]; then
    raw=${raw#\"}
    raw=${raw%\"}
  elif [[ $raw == \'*\' ]]; then
    raw=${raw#\'}
    raw=${raw%\'}
  fi

  h=$(_luo_home)
  _luo_init_files
  r=$(_luo_registry)

  if _luo_arg_is_script_path "$raw"; then
    kind=file
    p=$raw
    [[ $p == \~/* ]] && p="${HOME}/${p#\~/}"
    [[ $p == \~ ]] && p=$HOME
    src_abs=${p:A}
    [[ -n $dest_name ]] || dest_name=${src_abs:t}
    [[ $dest_name == */* ]] && { print -u2 "luo add: -n 不得包含路径分隔符"; return 1 }

    dest="$h/scripts/$dest_name"
    relpath="scripts/$dest_name"

    if [[ -e $dest || -L $dest ]]; then
      if [[ $force -eq 1 ]]; then
        command rm -f "$dest"
      else
        print -u2 "luo add: 目标已存在: $dest （使用 -f 覆盖）"
        return 1
      fi
    fi

    if _luo_name_in_registry "$dest_name"; then
      if [[ $force -eq 1 ]]; then
        _luo_remove_registry_row_by_name "$dest_name"
      else
        print -u2 "luo add: 注册表中已有同名条目: $dest_name （使用 -f 覆盖）"
        return 1
      fi
    fi

    if [[ -z $desc ]]; then
      desc=$(_luo_desc_from_script "$src_abs")
      [[ -z $desc ]] && desc="no description"
    fi
    desc=$(_luo_desc_one_line "$desc")

    command ln -sf "$src_abs" "$dest" || return 1
    if [[ ! -x $src_abs ]]; then
      command chmod +x "$src_abs" 2>/dev/null || true
    fi

    _luo_registry_line "$dest_name" "$desc" "file" "$relpath" >>"$r"
    print -r -- "已登记脚本(file): $dest_name -> $dest"
    return 0
  fi

  kind=shell
  payload=$raw
  [[ -n $payload ]] || { print -u2 "luo add: 命令为空"; return 1 }

  local auto_name=0
  if [[ -z $dest_name ]]; then
    auto_name=1
    dest_name=$(_luo_default_name_from_shell "$payload")
  fi
  [[ $dest_name == */* ]] && { print -u2 "luo add: -n 不得包含路径分隔符"; return 1 }

  local -a shell_dups
  if _luo_shell_payload_key "$payload" &>/dev/null; then
    shell_dups=(${(f)$(_luo_matching_shell_names_for_payload_key "$payload")})
  else
    shell_dups=()
  fi

  if (( ${#shell_dups[@]} > 0 )); then
    if [[ $force -eq 1 ]]; then
      local n
      for n in $shell_dups; do
        _luo_remove_registry_row_by_name "$n"
      done
    elif (( ${#shell_dups[@]} == 1 )) && [[ $shell_dups[1] == "$dest_name" ]]; then
      print -r -- "luo add: 已存在相同登记（名称与命令均一致），跳过"
      return 0
    elif [[ $auto_name -eq 1 ]]; then
      print -r -- "luo add: 已存在相同命令（登记名: ${(j:，)shell_dups}），跳过"
      return 0
    elif [[ -t 0 ]]; then
      print -u2 "luo add: 已存在相同命令，当前登记名: ${(j:，)shell_dups}"
      print -u2 "luo add: 命令: $payload"
      read -q '?是否删除上述条目并改为当前这一条？[y/N] ' || { print -u2 ""; return 1 }
      print -u2 ""
      local n
      for n in $shell_dups; do
        _luo_remove_registry_row_by_name "$n"
      done
    else
      print -u2 "luo add: 已存在相同命令（登记名: ${(j:，)shell_dups}），非交互终端请使用 -f"
      return 1
    fi
  fi

  if [[ $auto_name -eq 1 ]]; then
    dest_name=$(_luo_unique_default_name "$dest_name")
  elif _luo_name_in_registry "$dest_name"; then
    if [[ $force -eq 1 ]]; then
      _luo_remove_registry_row_by_name "$dest_name"
    else
      print -u2 "luo add: 注册表中已有同名条目: $dest_name （使用 -f 覆盖）"
      return 1
    fi
  fi

  if [[ -z $desc ]]; then
    local desc_src
    desc_src=$(_luo_desc_one_line "$payload")
    if (( ${#desc_src} > 72 )); then
      desc="${desc_src[1,72]}…"
    else
      desc=$desc_src
    fi
  fi
  desc=$(_luo_desc_one_line "$desc")

  _luo_registry_line "$dest_name" "$desc" "shell" "$payload" >>"$r"
  print -r -- "已登记命令(shell): $dest_name"
}

_luo_build_add_command_from_paste() {
  local pasted=$1 first rest tok payload_first payload cmd arg
  local -a words add_args pass_args payload_words
  [[ $pasted == *$'\n'* ]] || return 1
  first=${pasted%%$'\n'*}
  rest=${pasted#*$'\n'}
  words=(${(z)first}) || return 1
  (( ${#words[@]} >= 2 )) || return 1
  [[ $words[1] == luo && $words[2] == add ]] || return 1

  add_args=("${words[@]:2}")
  while (( ${#add_args[@]} > 0 )); do
    tok=$add_args[1]
    case $tok in
      -f)
        pass_args+=("$tok")
        shift add_args
        ;;
      -n|-d)
        (( ${#add_args[@]} >= 2 )) || return 1
        pass_args+=("$tok" "$add_args[2]")
        shift 2 add_args
        ;;
      -)
        shift add_args
        break
        ;;
      -*)
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  payload_words=("$add_args[@]")
  payload_first="${(j: :)payload_words}"
  if [[ -n $payload_first ]]; then
    payload=$payload_first$'\n'$rest
  else
    payload=$rest
  fi
  [[ -n $payload ]] || return 1

  cmd="print -r -- ${(q)payload} | luo add"
  if (( ${#pass_args[@]} > 0 )); then
    for arg in $pass_args; do
      cmd+=" ${(q)arg}"
    done
  fi
  cmd+=" -"
  print -r -- "$cmd"
}

_luo_bracketed_paste() {
  local pasted cmd
  zle .bracketed-paste pasted
  if [[ -z $BUFFER ]]; then
    cmd=$(_luo_build_add_command_from_paste "$pasted")
    if [[ -n $cmd ]]; then
      BUFFER=$cmd
      CURSOR=${#BUFFER}
      zle accept-line
      return
    fi
  fi
  LBUFFER+=$pasted
  zle -f yank 2>/dev/null || true
}

# 选中后把命令填入下一行的 ZLE 缓冲（print -z）。
# 直接在 _luo_pick 里调 print -z 不可靠：fzf 退出后终端状态未完全还原，zsh 重绘
# prompt 时会把 ZLE 缓冲抹掉。改为在 precmd 钩子里调用，此时 fzf 已彻底退出、
# 终端已还原，print -z 能稳定把命令放到命令行上。
typeset -g _LUO_PENDING_CMD=""

_luo_precmd_inject() {
  [[ -n $_LUO_PENDING_CMD ]] || return
  local c=$_LUO_PENDING_CMD
  _LUO_PENDING_CMD=""
  add-zsh-hook -d precmd _luo_precmd_inject 2>/dev/null
  print -z -- "$c"
}

_luo_commit_pick_command() {
  local text=$1
  if [[ ! -o interactive ]]; then
    print -u2 "luo: 非交互 shell，命令为：$text" >&2
    return 1
  fi
  _LUO_PENDING_CMD=$text
  autoload -Uz add-zsh-hook 2>/dev/null
  add-zsh-hook precmd _luo_precmd_inject 2>/dev/null
}

_luo_trim_outer_space() {
  local s=$1
  while [[ $s == [[:space:]]* ]]; do
    s=${s#[[:space:]]}
  done
  while [[ $s == *[[:space:]] ]]; do
    s=${s%[[:space:]]}
  done
  print -r -- "$s"
}

_luo_alias_form_for_command() {
  local cmd=$1 cmd_cmp cmd_key alias_name alias_value alias_cmp alias_key suffix
  local alias_script_payload alias_script_key
  local best_name= best_suffix=
  integer alias_len best_len=0

  cmd_cmp=$(_luo_trim_outer_space "$cmd")
  [[ -n $cmd_cmp ]] || { print -r -- "$cmd"; return 1; }
  cmd_key=$(_luo_shell_payload_key "$cmd_cmp" 2>/dev/null) || cmd_key=

  for alias_name in ${(ok)aliases}; do
    alias_value=${aliases[$alias_name]}
    alias_cmp=$(_luo_trim_outer_space "$alias_value")
    [[ -n $alias_name && -n $alias_cmp ]] || continue

    alias_script_payload=$(_luo_alias_script_payload_from_alias_value "$alias_cmp" 2>/dev/null) || alias_script_payload=
    if [[ -n $alias_script_payload && -n $cmd_key ]]; then
      alias_script_key=$(_luo_shell_payload_key "$alias_script_payload" 2>/dev/null) || alias_script_key=
      if [[ -n $alias_script_key && $alias_script_key == "$cmd_key" ]]; then
        best_name=$alias_name
        best_suffix=
        break
      fi
    fi

    suffix=
    alias_len=0
    if [[ $cmd_cmp == "$alias_cmp" ]]; then
      alias_len=${#alias_cmp}
    elif [[ $cmd_cmp == "$alias_cmp"[[:space:]]* ]]; then
      suffix=${cmd_cmp#$alias_cmp}
      while [[ $suffix == [[:space:]]* ]]; do
        suffix=${suffix#[[:space:]]}
      done
      alias_len=${#alias_cmp}
    elif [[ -n $cmd_key ]]; then
      alias_key=$(_luo_shell_payload_key "$alias_cmp" 2>/dev/null) || alias_key=
      if [[ -n $alias_key && $alias_key == "$cmd_key" ]]; then
        alias_len=${#alias_key}
      else
        continue
      fi
    else
      continue
    fi

    if (( alias_len > best_len )); then
      best_name=$alias_name
      best_suffix=$suffix
      best_len=$alias_len
    fi
  done

  if [[ -n $best_name ]]; then
    if [[ -n $best_suffix ]]; then
      print -r -- "$best_name $best_suffix"
    else
      print -r -- "$best_name"
    fi
    return 0
  else
    print -r -- "$cmd"
    return 1
  fi
}

_luo_fzf_supports_key() {
  local key=$1
  [[ -n $key ]] || return 1
  printf 'x\n' | command fzf --filter=x --expect="$key" >/dev/null 2>&1
}

_luo_alias_pick_key() {
  local key=${LUO_ALIAS_KEY:-ctrl-a}
  if _luo_fzf_supports_key "$key"; then
    print -r -- "$key"
    return 0
  fi
  if [[ $key != ctrl-a ]] && _luo_fzf_supports_key ctrl-a; then
    if [[ -n ${LUO_ALIAS_KEY:-} ]]; then
      print -u2 "luo: 当前 fzf 不支持快捷键 '$key'，本次改用 ctrl-a。"
    fi
    print -r -- ctrl-a
    return 0
  fi
  print -r -- alt-enter
}

_luo_alias_pick_key_label() {
  local key=$1
  case $key in
    alt-enter) print -r -- "Option+Enter" ;;
    ctrl-a) print -r -- "Ctrl+A" ;;
    *) print -r -- "$key" ;;
  esac
}

_luo_zshrc_file() {
  print -r -- "${ZDOTDIR:-$HOME}/.zshrc"
}

_luo_zshrc_source_line() {
  local f="$(_luo_home)/luo.zsh"
  print -r -- "[ -f ${(qq)f} ] && source ${(qq)f}"
}

_luo_zshrc_validate_luo_regions() {
  local zshrc=$1
  [[ -f $zshrc ]] || return 0
  command awk \
    -v rb='# >>> luo script hub' \
    -v re='# <<< luo script hub' \
    -v ab='# >>> luo aliases' \
    -v ae='# <<< luo aliases' '
      $0 == rb { rb_count++; rb_line = NR }
      $0 == re { re_count++; re_line = NR }
      $0 == ab { ab_count++; ab_line = NR }
      $0 == ae { ae_count++; ae_line = NR }
      END {
        if ((rb_count == 0 && re_count > 0) || (rb_count > 0 && re_count == 0) || rb_count > 1 || re_count > 1) exit 1
        if (rb_count == 1 && rb_line >= re_line) exit 1
        if ((ab_count == 0 && ae_count > 0) || (ab_count > 0 && ae_count == 0) || ab_count > 1 || ae_count > 1) exit 1
        if (ab_count == 1) {
          if (ab_line >= ae_line) exit 1
          if (rb_count != 1) exit 1
          if (!(rb_line < ab_line && ae_line < re_line)) exit 1
        }
      }
    ' "$zshrc"
}

_luo_shell_alias_name_valid() {
  local name=$1
  if [[ -z $name || $name == *[[:space:]]* || $name == */* || $name == *=* || $name == *\"* || $name == *\'* || $name == *\\* || $name == -* ]]; then
    print -u2 "luo alias create: alias 名不能含空格、斜杠、等号、引号、反斜杠，也不能以 - 开头。"
    return 1
  fi
  if [[ $name == luo ]]; then
    print -u2 "luo alias create: 不能使用 'luo' 作为 alias 名（会覆盖主命令）。"
    return 1
  fi
  if [[ -n ${_LUO_CURRENT_ALIAS:-} && $name == "$_LUO_CURRENT_ALIAS" ]]; then
    print -u2 "luo alias create: 不能使用 '$name'，它已经是 luo cmd 的快捷函数。"
    return 1
  fi
  return 0
}

_luo_zshrc_save_shell_alias() {
  local name=$1 value=$2 zshrc tmp alias_line source_line custom_home
  zshrc=$(_luo_zshrc_file)
  mkdir -p "${zshrc:h}" || return 1
  [[ -f $zshrc ]] || : >"$zshrc"

  if ! _luo_zshrc_validate_luo_regions "$zshrc"; then
    print -u2 "luo: $zshrc 中 luo marker 异常，未写入 alias。请检查 # >>>/# <<< luo script hub 与 luo aliases 区域。"
    return 1
  fi

  alias_line="alias ${name}=${(qq)value}"
  source_line=$(_luo_zshrc_source_line)
  if [[ $(_luo_home) != "$HOME/.luo" ]]; then
    local luo_home=$(_luo_home)
    custom_home="export LUO_HOME=${(qq)luo_home}"
  fi

  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-zshrc.XXXXXX")
  LUO_ALIAS_LINE="$alias_line" LUO_SOURCE_LINE="$source_line" LUO_CUSTOM_HOME="$custom_home" command awk \
    -v rb='# >>> luo script hub' \
    -v re='# <<< luo script hub' \
    -v ab='# >>> luo aliases' \
    -v ae='# <<< luo aliases' \
    -v n="$name" '
      BEGIN {
        line = ENVIRON["LUO_ALIAS_LINE"]
        src = ENVIRON["LUO_SOURCE_LINE"]
        custom = ENVIRON["LUO_CUSTOM_HOME"]
        in_alias = 0
        saw_block = 0
        saw_alias = 0
      }
      $0 == rb { saw_block = 1; print; next }
      $0 == ab { saw_alias = 1; in_alias = 1; print; next }
      $0 == ae { print line; print; in_alias = 0; next }
      $0 == re {
        if (!saw_alias) {
          print ab
          print line
          print ae
        }
        print
        next
      }
      in_alias {
        if (index($0, "alias " n "=") == 1) next
        print
        next
      }
      { print }
      END {
        if (!saw_block) {
          print ""
          print rb
          if (custom != "") print custom
          print src
          print ab
          print line
          print ae
          print re
        }
      }
    ' "$zshrc" >"$tmp" || return 1
  command mv -f "$tmp" "$zshrc"
}

_luo_alias_script_dir() {
  print -r -- "$(_luo_home)/alias-scripts"
}

_luo_alias_script_path() {
  local name=$1
  print -r -- "$(_luo_alias_script_dir)/${name}.zsh"
}

_luo_command_needs_current_shell() {
  local cmd=$1 line trimmed
  local -a lines
  lines=("${(@f)cmd}")
  for line in $lines; do
    trimmed=$(_luo_trim_outer_space "$line")
    [[ -z $trimmed || $trimmed == \#* ]] && continue
    case $trimmed in
      cd(|[[:space:]]*)|pushd(|[[:space:]]*)|popd(|[[:space:]]*)|export[[:space:]]*|unset[[:space:]]*|alias[[:space:]]*|unalias[[:space:]]*|source[[:space:]]*|.[[:space:]]*)
        return 0
        ;;
    esac
  done
  return 1
}

_luo_write_alias_script() {
  local name=$1 body=$2 script_file tmp dir
  dir=$(_luo_alias_script_dir)
  script_file=$(_luo_alias_script_path "$name")
  mkdir -p "$dir" || return 1

  if [[ -e $script_file && ! -f $script_file ]]; then
    print -u2 "luo: alias 脚本路径已存在但不是普通文件: $script_file"
    return 1
  fi

  tmp=$(mktemp "${TMPDIR:-/tmp}/luo-alias-script.XXXXXX")
  {
    print -r -- "#!/usr/bin/env zsh"
    print -r -- "# Managed by luo alias: $name"
    print -r -- "# luo:payload-begin"
    print -r -- "$body"
  } >"$tmp" || return 1
  command chmod 700 "$tmp" 2>/dev/null || true
  command mv -f "$tmp" "$script_file" || return 1
  command chmod 700 "$script_file" 2>/dev/null || true
}

_luo_alias_script_payload() {
  local script_file=$1 line in_payload=0
  [[ -f $script_file ]] || return 1
  while IFS= read -r line || [[ -n $line ]]; do
    if (( in_payload )); then
      print -r -- "$line"
    elif [[ $line == "# luo:payload-begin" ]]; then
      in_payload=1
    fi
  done <"$script_file"
  (( in_payload )) || return 1
}

_luo_alias_script_payload_from_alias_value() {
  local value=$1 script_file dir
  local -a words
  words=(${(z)value}) || return 1
  if [[ ${words[1]} == zsh && -n ${words[2]} ]]; then
    script_file=${(Q)words[2]}
  elif [[ ${words[1]} == source || ${words[1]} == . ]] && [[ -n ${words[2]} ]]; then
    script_file=${(Q)words[2]}
  else
    return 1
  fi
  dir="$(_luo_alias_script_dir)/"
  [[ ${script_file:A} == ${dir:A}/* || ${script_file:A} == ${dir:A} ]] || return 1
  _luo_alias_script_payload "${script_file:A}"
}

_luo_alias_value_for_command() {
  local name=$1 cmd=$2 mode=run script_path
  if [[ $cmd == *$'\n'* || $cmd == *$'\r'* ]]; then
    if _luo_command_needs_current_shell "$cmd"; then
      print -u2 -r -- ""
      print -u2 "luo: 这段多行命令看起来会修改当前 shell（如 cd/export/alias/source）。"
      if [[ -t 0 ]]; then
        read -q "?alias 执行时用 source 运行脚本，让它影响当前 shell？[y/N] " && mode=source
        print -u2 ""
      fi
    fi
    script_path=$(_luo_alias_script_path "$name")
    if [[ $mode == source ]]; then
      print -r -- "source ${(q)script_path}"
    else
      print -r -- "zsh ${(q)script_path}"
    fi
  else
    print -r -- "$cmd"
  fi
}

_luo_create_shell_alias_for_command() {
  local cmd=$1 name existing alias_value
  if [[ ! -t 0 ]]; then
    print -u2 "luo: 非交互终端，无法创建 alias。"
    return 1
  fi

  print -r -- ""
  print -r -- "luo: 未找到匹配 alias。"
  if [[ $cmd == *$'\n'* || $cmd == *$'\r'* ]]; then
    print -r -- "命令为多行内容；将创建 luo 托管脚本，并在 ~/.zshrc 的 luo aliases 区域写入单行 alias。"
  else
    print -r -- "命令: $cmd"
  fi

  while true; do
    read -r "?创建 alias 名称（留空取消，完成后返回 luo cmd）: " name || {
      print ""
      return 1
    }
    name=$(_luo_trim_outer_space "$name")
    [[ -n $name ]] || {
      print -r -- "luo: 已取消创建 alias。"
      return 1
    }
    _luo_shell_alias_name_valid "$name" || continue
    alias_value=$(_luo_alias_value_for_command "$name" "$cmd") || return 1

    if [[ -n ${aliases[$name]+x} ]]; then
      existing=${aliases[$name]}
      if [[ $existing == "$alias_value" ]]; then
        if [[ $cmd == *$'\n'* || $cmd == *$'\r'* ]]; then
          _luo_write_alias_script "$name" "$cmd" || return 1
        fi
        _luo_zshrc_save_shell_alias "$name" "$alias_value" || return 1
        alias "${name}=${alias_value}" || return 1
        print -r -- "luo: alias 已存在且内容相同: ${name}=${(qq)alias_value}"
        print -r -- "luo: 返回 cmd 选择器。"
        return 0
      fi
      print -u2 "luo: alias '$name' 已存在: alias ${name}=${(qq)existing}"
      read -q "?覆盖？[y/N] " || {
        print ""
        continue
      }
      print ""
    elif command -v "$name" >/dev/null 2>&1; then
      print -u2 "luo: '$name' 已是系统中存在的命令。"
      read -q "?仍要创建 alias 覆盖？[y/N] " || {
        print ""
        continue
      }
      print ""
    fi

    if [[ $cmd == *$'\n'* || $cmd == *$'\r'* ]]; then
      _luo_write_alias_script "$name" "$cmd" || return 1
    fi
    _luo_zshrc_save_shell_alias "$name" "$alias_value" || return 1
    alias "${name}=${alias_value}" || return 1
    print -r -- "luo: 已创建 alias: ${name}=${(qq)alias_value}"
    print -r -- "luo: 返回 cmd 选择器。"
    return 0
  done
}

_luo_pick() {
  local h line name desc kind payload fullpath cmd
  local -a fl
  local out hdr pr color cnt picked_key alias_key alias_key_label
  integer del_mode=${LUO_DELETE_START:-0}
  unset LUO_DELETE_START

  _luo_require_fzf || return
  _luo_init_files
  _luo_sync_merge ""
  h=$(_luo_home)
  alias_key=$(_luo_alias_pick_key)
  alias_key_label=$(_luo_alias_pick_key_label "$alias_key")

  while true; do
    if (( del_mode )); then
      hdr=$'\e[32m[删除模式]\e[0m Enter 删除 | Fn+F2 退出删除模式 | Tab 缩小 | Ctrl+N / Esc 退出'
      pr=$'\e[1;32mDEL>\e[0m '
      color='prompt:#00cc00,pointer:#00ff00,fg+:#ccffcc,border:#00aa00'
    else
      hdr="Tab 缩小 | Enter 完整命令 | ${alias_key_label} 别名/创建 | "$'\e[33mFn+F2\e[0m 删除模式（绿色）| Ctrl+N / Esc 退出'
      pr='> '
      color=
    fi

    out=$(
      _luo_registry_sorted_fourcol_lines |
        command fzf \
        --delimiter=$'\t' \
        --with-nth=1,2,3 \
        --nth=1,2,3,4 \
        --no-multi \
        +s \
        ${color:+--color="$color"} \
        --prompt="$pr" \
        --header="$hdr" \
        --expect="f2,$alias_key" \
        --bind='tab:change-query({1})' \
        --bind='ctrl-n:abort'
    ) || return 0
    [[ -n $out ]] || return 0

    fl=("${(@f)out}")
    picked_key=${fl[1]}
    if [[ $picked_key == f2 ]]; then
      del_mode=$(( 1 - del_mode ))
      continue
    fi

    # --expect 模式下：fl[1]=按键名（Enter时为空），fl[2]=选中行
    line=${fl[2]}
    [[ -n $line ]] || return 0

    _luo_parse_registry_line "$line" || return 1
    name=$_LUO_ROW[1]
    desc=$_LUO_ROW[2]
    kind=$_LUO_ROW[3]
    payload=$_LUO_ROW[4]
    [[ -n $name && -n $kind && -n $payload ]] || return 1

    if (( del_mode )); then
      [[ $picked_key == "$alias_key" ]] && continue
      cnt=$(_luo_usage_get "$name")
      cnt=$(( cnt + 0 ))
      if (( cnt > 30 )); then
        if [[ -t 0 ]]; then
          read -q "?该条目在 cmd 选择器中已使用 ${cnt} 次（>30），确认删除？[y/N] " || {
            print ""
            continue
          }
          print ""
        else
          print -u2 "luo: 非交互终端且使用次数 ${cnt}>30，未删除: $name"
          continue
        fi
      fi
      if _luo_remove_by_name "$name"; then
        _luo_usage_remove_name "$name"
      fi
      continue
    fi

    if [[ $kind == shell ]]; then
      cmd=$payload
      if [[ $picked_key == "$alias_key" ]]; then
        if ! cmd=$(_luo_alias_form_for_command "$cmd"); then
          _luo_create_shell_alias_for_command "$payload"
          continue
        fi
      fi
      _luo_usage_incr "$name"
      _luo_commit_pick_command "$cmd"
      return 0
    fi

    if [[ $kind != file ]]; then
      print -u2 "luo: 未知 kind: $kind"
      return 1
    fi

    fullpath="$h/$payload"
    if [[ ! -e $fullpath ]]; then
      print -u2 "luo: 文件不存在: $fullpath"
      return 1
    fi
    if [[ -x $fullpath ]]; then
      cmd=${(q)fullpath}
    else
      cmd="zsh ${(q)fullpath}"
    fi
    if [[ $picked_key == "$alias_key" ]]; then
      if ! cmd=$(_luo_alias_form_for_command "$cmd"); then
        _luo_create_shell_alias_for_command "$cmd"
        continue
      fi
    fi
    _luo_usage_incr "$name"
    _luo_commit_pick_command "$cmd"
    return 0
  done
}

luo() {
  local sub=${1:-}
  case $sub in
    cmd | pick)
      shift
      _luo_pick "$@"
      ;;
    help | usage | commands)
      shift
      _luo_usage
      ;;
    list)
      shift
      _luo_list "$@"
      ;;
    add)
      shift
      _luo_add "$@"
      ;;
    sync)
      shift
      _luo_sync "$@"
      ;;
    remove | rm)
      if [[ -n ${2-} ]]; then
        print -u2 "luo rm/remove: 不再接受名称参数；请执行: luo cmd，按 Fn+F2 进入删除模式"
        return 1
      fi
      LUO_DELETE_START=1
      _luo_pick
      ;;
    alias)
      shift
      _luo_alias_cmd "$@"
      ;;
    home)
      _luo_home
      ;;
    "" )
      _luo_usage
      ;;
    -h | --help)
      shift
      _luo_usage
      ;;
    *)
      print -u2 "luo: 未知子命令: $sub"
      _luo_usage
      return 1
      ;;
  esac
}

# ---- zsh 补全（子命令等）----
# 使用独立函数名 _luo_cmd_complete，避免与 $fpath 里名为 _luo 的系统补全片段冲突。
_luo_cmd_complete() {
  local sub

  if (( CURRENT == 2 )); then
    compadd help usage commands cmd pick list add sync remove rm alias home
    return
  fi

  sub=${words[2]:l}
  case $sub in
    add)
      _files "$@"
      ;;
    sync)
      if (( CURRENT == 3 )); then
        compadd -p -S '' -- -p
      else
        _default "$@"
      fi
      ;;
    *)
      _default "$@"
      ;;
  esac
}

_luo_register_compdef_once() {
  (( $+functions[compdef] )) || return 0
  compdef -r luo 2>/dev/null
  compdef _luo_cmd_complete luo 2>/dev/null
  add-zsh-hook -d precmd _luo_register_compdef_once 2>/dev/null
}

_luo_try_compdef() {
  (( $+functions[compdef] )) || return 0
  compdef -r luo 2>/dev/null
  compdef _luo_cmd_complete luo 2>/dev/null
}

if (( $+functions[compdef] )); then
  _luo_try_compdef
elif autoload -Uz add-zsh-hook 2>/dev/null; then
  add-zsh-hook precmd _luo_register_compdef_once
fi

if [[ -o interactive ]]; then
  zle -N bracketed-paste _luo_bracketed_paste 2>/dev/null || :
fi

# 若 zshrc 里先 source 本文件、后 compinit，第一次执行 luo 时再注册一次
# unfunction 在目标不存在时返回非 0，会导致「source 本文件」整体退出码为 1
unfunction _luo 2>/dev/null || :

# source 时自动加载用户设置的 luo cmd 快捷函数
_luo_alias_load
