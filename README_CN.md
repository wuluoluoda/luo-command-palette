# CmdRoster (luo)

> 命令行 & 脚本管理工具——把任意 shell 命令或脚本注册一次，随时通过模糊搜索秒找秒用。

[English](README.md)

## 平台支持

| 平台 | Shell | 对应版本 |
|------|-------|---------|
| macOS | **zsh** | `zsh/` |
| Linux（原生） | **zsh** | `zsh/` |
| Windows（WSL 2） | **zsh** | `zsh/` |
| Windows（PowerShell） | **pwsh** | `pwsh/` |
| Linux / macOS（PowerShell Core） | **pwsh** | `pwsh/` |

仓库提供 **两个独立版本**，分别位于 `zsh/` 和 `pwsh/` 目录。  
两个版本共用相同的 TSV registry 格式，可共享同一个 `~/.luo/` 数据目录。

### Windows / Linux / macOS 上的 PowerShell 是否一致？

**PowerShell 7+（`pwsh`）** 在 Windows、Linux、macOS 上语言与模块面基本一致，本仓库的 `pwsh/install.ps1`、`pwsh/luo.ps1` 主要面向 **PowerShell 7+**。**Windows PowerShell 5.1**（`powershell.exe`）仅存在于 Windows，部分 API 与默认值与 7+ 略有差异；安装脚本仍可在 5.1 上运行（见下文要求）。

---

## 按平台安装

### macOS

**zsh** — 一行安装（无需 `git clone`）：

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

**PowerShell（`pwsh`）** — 一行安装（无需 `git clone`）：

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | pwsh
```

**zsh** 安装脚本会在缺少 **fzf** 时用 Homebrew 安装；**pwsh** 在 macOS 上同样通过 `brew` 安装 fzf。

安装后立刻激活：**zsh** 新开终端会从 `~/.zshrc` 加载，当前会话可执行：

```bash
source ~/.luo/luo.zsh
```

**pwsh**：

```powershell
. "$HOME/.luo/luo.ps1"
```

---

### Linux（原生）

**zsh** — 一行安装（无需 `git clone`）：

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

**PowerShell（`pwsh`）** — 一行安装（无需 `git clone`）：

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | pwsh
```

**zsh** 安装脚本会按系统尝试 `apt-get` / `pacman` / `dnf` / `yum` / `zypper` 等安装 fzf。**pwsh** 在 Linux 上使用同类包管理器（`winget` 仅在 Windows 上使用）。

激活方式与 macOS 相同：`source ~/.luo/luo.zsh` 或 `. "$HOME/.luo/luo.ps1"`。

---

### Windows

**PowerShell**（Windows Terminal 等）— 一行安装（无需 `git clone`）：

```powershell
irm https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | iex
```

**WSL 2 + zsh**：请在 **WSL 里的 Linux 终端**（如 Ubuntu）中执行上面的 **Linux zsh** 一行命令，不要在 Windows PowerShell 里直接跑 zsh 安装脚本。

**PowerShell** 安装脚本会依次尝试 `winget`、`scoop`、`chocolatey` 安装 fzf。

**WSL 2 初次安装**（装好后按 Linux zsh 流程即可）：

```powershell
# PowerShell（管理员）
wsl --install
```

```bash
# Ubuntu（WSL）终端中
sudo apt-get update && sudo apt-get install -y zsh fzf
chsh -s "$(which zsh)"
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

---

## 不用 `git clone` 获取源码

可下载仓库快照，解压后在目录内运行安装脚本（以下链接默认分支为 **`main`**；若你使用其他默认分支请替换 URL）。

**macOS / Linux（tar.gz）：**

```bash
curl -fsSL -L -o /tmp/cmdroster.tar.gz https://github.com/wuluoluoda/cmdroster/archive/refs/heads/main.tar.gz
tar xzf /tmp/cmdroster.tar.gz -C /tmp
cd /tmp/cmdroster-main
bash zsh/install.sh          # zsh 版
# 可选：pwsh -File ./pwsh/install.ps1
```

**Windows（ZIP，PowerShell）：**

```powershell
$u = 'https://github.com/wuluoluoda/cmdroster/archive/refs/heads/main.zip'
$z = Join-Path $env:TEMP 'cmdroster-main.zip'
Invoke-WebRequest $u -OutFile $z
Expand-Archive $z -DestinationPath $env:TEMP -Force
Set-Location (Join-Path $env:TEMP 'cmdroster-main')
.\pwsh\install.ps1           # PowerShell 版
# 可选：wsl bash zsh/install.sh   # 在 WSL 里装 zsh 版
```

---

## 克隆整个仓库（一次拿到 zsh + pwsh 全部文件）

```bash
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster

# zsh 版（macOS / Linux / WSL）
bash zsh/install.sh

# PowerShell 版（在你日常使用的环境里执行 pwsh）
pwsh -File ./pwsh/install.ps1
# Windows 上也可：.\pwsh\install.ps1
```

`pwsh/install.ps1` 需要 **Windows PowerShell 5.1+** 或 **PowerShell 7+（`pwsh`，推荐）**。

安装完成后，**pwsh** 新会话会从 `$PROFILE` 自动加载；当前会话可执行：

```powershell
. "$HOME/.luo/luo.ps1"
```

---

## 快速上手

```bash
luo add "ping -c 4 google.com"   # 登记一条 shell 命令
luo add ./deploy.sh               # 登记一个本地脚本
luo help                          # fzf 选命令，Enter 后命令出现在命令行
luo alias ql                      # 把 ql 设为 luo help 的快捷方式
```

PowerShell 版专属：按 **Ctrl+Shift+L** 直接弹出 fzf，选中后命令直接注入命令行（最佳体验）。

---

## 命令一览

| 命令 | 说明 |
|------|------|
| `luo help` | 交互式模糊选择（fzf），Enter 将命令放到命令行 |
| `luo list` | 打印所有已登记的条目 |
| `luo add [-n 名称] [-d 简介] [-f] <文本>` | 登记一条 shell 命令或脚本路径 |
| `luo sync [-p]` | 扫描 `scripts/` 补全缺失条目；`-p` 删除失效的 file 条目 |
| `luo rm` / `luo remove` | 直接进入**删除模式**（绿色界面），Enter 删除选中条目 |
| `luo alias [名字]` | 设置 `luo help` 的快捷命令；`luo alias off` 取消 |
| `luo home` | 打印 `LUO_HOME` |

### 删除模式

在 fzf 界面按 **Fn+F2**（zsh 版）或 **F2**（pwsh 版）切换删除模式（绿色界面）。  
已使用超过 30 次的条目删除前会交互确认。

### luo alias — luo help 的快捷方式

```bash
luo alias ql       # 把 ql 设为 luo help 的快捷命令
ql                 # 等同于 luo help
luo alias          # 查看当前快捷命令
luo alias off      # 取消快捷命令
```

别名名称保存在 `~/.luo/alias`，每次新开终端自动加载。

### luo help 如何把命令放到命令行

**zsh 版**：借助 `precmd` 钩子，fzf 退出后终端状态还原完毕时再执行 `print -z`，稳定可靠。

**pwsh 版**：在 prompt 函数中包装一帧，让 `PSConsoleReadLine::Insert()` 在 PSReadLine 就绪时触发。快捷键 `Ctrl+Shift+L` 始终稳定注入。

---

## 自定义安装目录

```bash
LUO_HOME=~/my-luo ./zsh/install.sh     # zsh 版
LUO_HOME=~/my-luo ./pwsh/install.ps1   # pwsh 版
```

---

## 目录结构

```
cmdroster/
├── zsh/
│   ├── luo.zsh            # zsh 版（macOS / Linux / WSL 2）
│   ├── install.sh         # bash 安装脚本
│   └── registry.tsv.example
├── pwsh/
│   ├── luo.ps1            # PowerShell 版（Windows / Linux / macOS）
│   ├── install.ps1        # PowerShell 安装脚本
│   └── registry.tsv.example
├── README.md
├── README_CN.md
└── LICENSE

~/.luo/                    # 默认 LUO_HOME（zsh 与 pwsh 可共用）
├── luo.zsh  或  luo.ps1
├── registry.tsv           # name / description / kind / payload
├── usage.tsv              # 每条命令的使用次数
├── alias                  # 当前快捷命令名
└── scripts/               # 托管的脚本与符号链接
```

---

## 许可证

MIT © [wuluoluoda](https://github.com/wuluoluoda)
