# luo — 你的 Shell 命令面板

**luo** 是一个面向 **macOS zsh** 的轻量 **Shell 命令面板**。把你决定保留的命令或脚本登记一次，之后随时用 **fzf** 搜索，选中后先填回命令行，由你确认、修改后再执行。

它不试图记住你敲过的所有历史命令；它只保存你主动沉淀下来的命令。

命令行工具名叫 **`luo`**（三个字母，好打）。数据默认存放在 **`~/.luo/`**（可通过 `LUO_HOME` 自定义）。

> English documentation: [README.md](README.md)

## 功能亮点

- **一行安装，开箱即用**：安装脚本会复制 `luo.zsh`、初始化数据目录、检查 fzf，并把加载语句写入 zsh 实际读取的 `.zshrc` 固定 luo 区域。
- **命令先预备，不直接执行**：从 `luo cmd` 选中条目后只填到命令行，先检查、可编辑，再按 Enter 执行。
- **命令和脚本统一管理**：短 shell 片段、多行命令、脚本文件都能登记到同一个 fzf 菜单里。
- **纯文本个人 runbook**：条目保存在 `registry.tsv`，容易阅读、diff、备份和审计。
- **智能 alias 工作流**：在 `luo cmd` 中按 **Ctrl+A** 会查询现有 alias，优先用 alias 形式填入；没有 alias 时可现场创建。
- **安全写 `.zshrc`**：创建 alias 只写 `# >>> luo aliases` 与 `# <<< luo aliases` 之间，marker 异常会拒绝写入。
- **多行 alias 更稳**：多行命令会生成 `~/.luo/alias-scripts/<alias>.zsh` 托管脚本，`.zshrc` 只保留一行 alias。
- **可回收、可维护**：支持删除模式、使用次数统计、同名/冲突确认、旧 registry 自动兼容。

## 依赖

| 工具 | 安装方式 |
|------|---------|
| zsh | macOS 自带 |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` |

## 安装

### 一行命令安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/luo-command-palette/main/install.sh | bash
```

安装脚本会自动检测 fzf，若未安装会询问是否通过 Homebrew 安装。

### 克隆后安装

```bash
git clone https://github.com/wuluoluoda/luo-command-palette.git
cd luo-command-palette
./install.sh
```

安装完成后，在**当前终端**执行一行激活（新开终端会从 `~/.zshrc` 自动加载）：

```bash
source ~/.luo/luo.zsh
```

### 自定义安装目录

```bash
LUO_HOME=~/my-tools ./install.sh
```

若 `LUO_HOME` 不是默认的 `~/.luo`，安装脚本会在 `~/.zshrc` 里写入 `export LUO_HOME=…`。

安装脚本会定位 zsh 实际读取的配置文件：`${ZDOTDIR:-$HOME}/.zshrc`。这表示若你设置了 `ZDOTDIR`，会写入 `$ZDOTDIR/.zshrc`；否则写入常见的 `~/.zshrc`。所有 luo 自动维护内容都集中在 `# >>> luo script hub` 与 `# <<< luo script hub` 之间，其中 alias 只写入内部的 `# >>> luo aliases` 与 `# <<< luo aliases` 区域。外层 marker 继续保留旧的 "script hub" 字样，用来兼容已有安装。

## 快速上手

```bash
# 登记一条 shell 命令
luo add "caffeinate -di"

# 登记一个脚本（在 ~/.luo/scripts/ 下建软链接）
luo add ./my-script.sh

# 给条目起一个好记的名字
luo add -n wake "caffeinate -di"

# 先看 luo 自带有哪些子命令（list、alias、add…）；与常见 CLI 一致也可用 luo help
luo help

# 打开已登记条目的 fzf 交互菜单，回车后命令出现在命令行
luo cmd

# 在 luo cmd 中按 Ctrl+A：优先填入 alias 形式，无 alias 时引导创建

# 设置一个更短的快捷命令（例如 ql），以后直接 ql 即可
luo alias ql
ql
```

## 命令一览

**说明：** `luo help` 现为 **内置子命令说明**（与 `--help` 同义）。打开已登记条目的 fzf 请用 **`luo cmd`**（同义：`luo pick`）。若你用过旧版「`luo help` 打开 fzf」请改为 `luo cmd`。

| 命令 | 说明 |
|------|------|
| `luo` / `luo help` / `luo usage` / `luo commands` / `luo -h` / `--help` | 打印 **luo 工具自身的子命令说明** |
| `luo cmd` | 对已登记条目打开 **fzf**（字母序）；**Tab** 缩小范围；**Enter** 把完整命令填到命令行；**Ctrl+A** 查询当前 shell alias 并尽量用 alias 形式填入，无匹配时引导创建 alias；**Fn+F2** 切换删除模式；**Ctrl+N** / **Esc** 退出 |
| `luo pick` | 与 `luo cmd` 完全相同 |
| `luo add [选项] …` | 登记命令或脚本（见下文） |
| `luo list` | 打印全部条目（带表头的 TSV） |
| `luo sync [-p]` | 扫描 `scripts/` 补全缺失条目；`-p` 同时清理失效行 |
| `luo rm` / `luo remove` | 等同于 `luo cmd` 但直接进入删除模式 |
| `luo alias [名字]` | 设置 / 查看 / 取消 `luo cmd` 的快捷命令（见下文） |
| `luo home` | 打印当前 `LUO_HOME` |

### luo add 选项

| 选项 | 说明 |
|------|------|
| `-n <名称>` | 自定义显示名称（默认生成短名称，如 `cd-app`、`npm-dev`；重名自动加 `-2`） |
| `-d <简介>` | 自定义简介（脚本文件内可写 `# luo:desc …` 自动读取） |
| `-f` | 强制覆盖同名条目 |

**自动判定规则**：参数含 `/` 或以 `./` `../` 开头且文件存在 → 按**脚本**处理，在 `~/.luo/scripts/` 下建软链接；否则整段字符串视为 **shell 命令**。

```bash
luo add "npm run dev"               # shell 命令
luo add -n dev "npm run dev"        # 自定义名称
luo add                             # 然后粘贴多行 shell 命令，按 Ctrl-D 保存
luo add cd app                      # 也可把第一行接在 add 后面，继续粘贴后续行后按 Ctrl-D
pbpaste | luo add -                 # 或直接从剪贴板导入多行命令
luo add ./build.sh                  # 脚本（建软链接）
luo add ~/bin/deploy.sh             # 绝对路径脚本
luo add -f "npm run dev"            # 强制覆盖同名条目
```

多行 shell 命令可以直接粘贴，第一行也可以接在 `luo add` 后面；此时 `luo add` 会继续读取后续行，直到你按 `Ctrl-D` 保存，所以后续行不会继续交给 shell 执行。也可用单独参数 `-` 从标准输入读取，不需要手写 `\n`。名称默认生成短名称，例如 `cd app` 是 `cd-app`、`npm run dev` 是 `npm-dev`；若仍重名会自动追加 `-2`、`-3`。需要自定义名称时才使用 `-n <名称>`。它会安全存为单行 registry 记录；在 `luo cmd` 中选中后会还原为真实多行并填回命令行。

### luo alias — 设置快捷命令

不想每次输 `luo cmd`？给它起个任意不冲突的短名字：

```bash
luo alias ql        # 把 "ql" 设为 luo cmd 的快捷方式
ql                  # 直接打开交互菜单

luo alias           # 查看当前设置的快捷命令
luo alias off       # 取消快捷命令
```

快捷命令名保存在 `~/.luo/alias`，每次 `source luo.zsh` 时自动读取并定义对应函数，**新开终端无需任何额外操作**。改名时旧函数自动清理，不会残留。

> **注意**：若命令名与系统命令冲突，会警告并要求确认后再设置。

### luo cmd 如何把命令填到命令行

选中后，命令通过 `print -z` 写入 **ZLE 行编辑缓冲**（在 `precmd` 钩子里调用，确保 fzf 已彻底退出、终端状态已还原）。命令出现在提示符后，你可以修改，确认无误再按 **Enter** 执行。

普通模式下，若按 **Ctrl+A** 选中条目，`luo` 会在这一刻才查询当前 zsh 的 `alias` 表，并尽量把命令转换成第一个匹配的 alias 形式。例如已有 `alias gs='git status'`，选中 `git status -sb` 后按 **Ctrl+A**，命令行会预备为 `gs -sb`；普通 **Enter** 仍始终填入完整命令。

若没有匹配 alias，`luo` 会提示输入 alias 名称，创建后写入 `~/.zshrc` 的 luo 专区（`# >>> luo aliases` 到 `# <<< luo aliases` 之间），然后返回刚才的 `luo cmd` 选择器。单行命令会直接写为普通 alias；多行命令会保存为 `~/.luo/alias-scripts/<alias>.zsh` 托管脚本，`.zshrc` 中只写一行指向该脚本的 alias。默认快捷键是 fzf 明确支持的 **Ctrl+A**；如需改键，可用 `LUO_ALIAS_KEY` 指定实际发出的 fzf 键名。

创建 alias 时遵循这些规则：alias 名不能含空格、斜杠、等号、引号、反斜杠，也不能以 `-` 开头；不能使用 `luo` 或当前 `luo alias` 快捷函数名；若同名 alias 已存在且内容相同则直接成功，内容不同会询问是否覆盖；若名称与已有系统命令冲突，也会询问确认；多行命令若看起来会修改当前 shell（如 `cd`、`export`、`alias`、`source`），会询问是否用 `source` 方式运行脚本；若 `.zshrc` 中 luo marker 异常，则拒绝写入并提示手动修复。

### 删除模式

在 `luo cmd`（或 `luo pick`）界面按 **Fn+F2**（Mac 笔记本 F 行默认为媒体键，需 Fn）进入绿色的删除模式：

- **Enter** — 删除当前选中条目（`kind=file` 时同时删除 `scripts/` 下的软链接）
- 使用次数 **> 30** 的条目删除前会提示确认
- 再按 **Fn+F2** 退出删除模式，回到普通模式

也可直接 `luo rm` 打开菜单并自动进入删除模式。

## 目录结构

```
~/.luo/
├── luo.zsh          # 主逻辑（由 install.sh 安装/更新）
├── registry.tsv     # 条目数据库（制表符分隔，UTF-8）
├── usage.tsv        # 各条目使用次数（超过 30 次删除时提示确认）
├── alias            # 快捷命令名（一行纯文本，由 luo alias 写入）
├── alias-scripts/   # luo cmd 为多行 alias 生成的托管脚本
└── scripts/         # 已登记脚本的软链接目录
```

注册表列：`name`、`description`、`kind`（`shell` | `file`）、`payload`。新写入的字段会按需转义反斜杠、Tab 和换行，以保持一条记录只占一行。

## Tab 补全

`luo.zsh` 用 `compdef _luo_cmd_complete luo` 注册补全。需确保 `~/.zshrc` 中 **`compinit` 在 `source luo.zsh` 之前执行**，否则补全不生效。

## 卸载

```bash
./install.sh --uninstall
```

这会删除 `~/.luo/` 目录并从 `~/.zshrc` 移除 luo 配置块。之后请重新打开终端或执行 `exec zsh`。

## License

MIT — 详见 [LICENSE](LICENSE)。
