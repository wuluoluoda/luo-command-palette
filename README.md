# CmdRoster (luo)

> A command-line & script hub for your terminal — register any shell command or script once, then recall it instantly with fuzzy search.

[中文文档](README_CN.md)

## Platform support

| Platform | Shell | Version |
|----------|-------|---------|
| macOS | **zsh** | `zsh/` |
| Linux (native) | **zsh** | `zsh/` |
| Windows (WSL 2) | **zsh** | `zsh/` |
| Windows (PowerShell) | **pwsh** | `pwsh/` |
| Linux / macOS (PowerShell Core) | **pwsh** | `pwsh/` |

The repo ships **two independent versions** under `zsh/` and `pwsh/`.  
They share the same TSV registry format so you can keep one `~/.luo/` folder across both shells.

### PowerShell on Windows vs Linux vs macOS

**PowerShell 7+ (`pwsh`)** is the same language and module surface on Windows, Linux, and macOS — this repo’s `pwsh/install.ps1` and `pwsh/luo.ps1` target that stack. **Windows PowerShell 5.1** (the one named `powershell.exe`) is Windows-only and differs slightly in APIs and defaults; the installer still works on 5.1 where noted below.

---

## Install by platform

### macOS

**zsh** — one-liner (no `git clone`):

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

**PowerShell (`pwsh`)** — one-liner (no `git clone`):

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | pwsh
```

The **zsh** installer installs **fzf** via Homebrew if missing. The **pwsh** installer uses `brew` for fzf on macOS.

After **zsh** install, activate once (new terminals load `~/.zshrc` automatically):

```bash
source ~/.luo/luo.zsh
```

After **pwsh** install:

```powershell
. "$HOME/.luo/luo.ps1"
```

---

### Linux (native)

**zsh** — one-liner (no `git clone`):

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

**PowerShell (`pwsh`)** — one-liner (no `git clone`):

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | pwsh
```

The **zsh** installer uses `apt-get` / `pacman` / `dnf` / `yum` / `zypper` when available. The **pwsh** installer uses the same Linux package managers for **fzf** (`winget` is only used on Windows).

Activate: same as macOS (`source ~/.luo/luo.zsh` or `. "$HOME/.luo/luo.ps1"`).

---

### Windows

**PowerShell** (Windows Terminal, etc.) — one-liner (no `git clone`):

```powershell
irm https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/pwsh/install.ps1 | iex
```

**WSL 2 + zsh** — run the Linux **zsh** one-liner *inside* the WSL terminal (Ubuntu, etc.), not in Windows PowerShell.

The **PowerShell** installer installs **fzf** via `winget`, then **scoop**, then **Chocolatey** if needed.

**WSL 2 — first-time setup** (then use the Linux zsh flow):

```powershell
# PowerShell (Admin)
wsl --install
```

```bash
# Inside Ubuntu (WSL)
sudo apt-get update && sudo apt-get install -y zsh fzf
chsh -s "$(which zsh)"
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/zsh/install.sh | bash
```

---

## Source code without `git clone`

You can download a snapshot of the repo and run either installer from the extracted folder (branch **`main`** in the URLs below; replace if you use another default branch).

**macOS / Linux (tarball):**

```bash
curl -fsSL -L -o /tmp/cmdroster.tar.gz https://github.com/wuluoluoda/cmdroster/archive/refs/heads/main.tar.gz
tar xzf /tmp/cmdroster.tar.gz -C /tmp
cd /tmp/cmdroster-main
bash zsh/install.sh          # zsh version
# optional: pwsh -File ./pwsh/install.ps1
```

**Windows (ZIP, PowerShell):**

```powershell
$u = 'https://github.com/wuluoluoda/cmdroster/archive/refs/heads/main.zip'
$z = Join-Path $env:TEMP 'cmdroster-main.zip'
Invoke-WebRequest $u -OutFile $z
Expand-Archive $z -DestinationPath $env:TEMP -Force
Set-Location (Join-Path $env:TEMP 'cmdroster-main')
.\pwsh\install.ps1           # PowerShell version
# optional: wsl bash zsh/install.sh   # zsh via WSL
```

---

## Clone the repository (all variants in one checkout)

```bash
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster

# zsh edition (macOS / Linux / WSL)
bash zsh/install.sh

# PowerShell edition (Windows / Linux / macOS — run pwsh where you use it)
pwsh -File ./pwsh/install.ps1
# On Windows you can also:  .\pwsh\install.ps1
```

Requires **PowerShell 5.1+** (Windows) or **PowerShell 7+** (`pwsh`, recommended everywhere) for `pwsh/install.ps1`.

---

## Quick start

```bash
luo add "ping -c 4 google.com"   # register a shell command
luo add ./deploy.sh               # register a local script
luo help                          # fzf picker → Enter puts it on the command line
luo alias ql                      # set 'ql' as a short alias for luo help
```

PowerShell bonus: press **Ctrl+Shift+L** to open the picker directly in the readline buffer.

---

## Commands

| Command | Description |
|---------|-------------|
| `luo help` | Interactive fuzzy picker (fzf). Enter puts the command on the command line. |
| `luo list` | Print all registered entries. |
| `luo add [-n name] [-d desc] [-f] <text>` | Register a shell command or script path. |
| `luo sync [-p]` | Scan `scripts/` and fill missing entries; `-p` removes stale file entries. |
| `luo rm` / `luo remove` | Open picker in **delete mode** (green). Enter deletes the selected entry. |
| `luo alias [name]` | Set a short alias for `luo help`; `luo alias off` to remove. |
| `luo home` | Print `LUO_HOME`. |

### Delete mode

Press **Fn+F2** (zsh) or **F2** (pwsh) inside the picker to toggle delete mode (green UI).  
Entries used more than 30 times prompt for confirmation before deletion.

### luo alias — short alias for luo help

```bash
luo alias ql       # create 'ql' → calls luo help
ql                 # same as luo help
luo alias          # show current alias
luo alias off      # remove alias
```

The alias name is saved to `~/.luo/alias` and reloaded on every new shell.

### How luo help puts a command on the command line

**zsh version**: uses a `precmd` hook so `print -z` runs after fzf exits and the terminal state is clean.

**pwsh version**: wraps the `prompt` function for one tick so `PSConsoleReadLine::Insert()` fires when PSReadLine is ready. The key binding `Ctrl+Shift+L` always works inline.

---

## Custom install directory

```bash
LUO_HOME=~/my-luo ./zsh/install.sh     # zsh
LUO_HOME=~/my-luo ./pwsh/install.ps1   # pwsh
```

---

## Repository layout

```
cmdroster/
├── zsh/
│   ├── luo.zsh            # zsh version (macOS / Linux / WSL 2)
│   ├── install.sh         # bash installer
│   └── registry.tsv.example
├── pwsh/
│   ├── luo.ps1            # PowerShell version (Windows / Linux / macOS)
│   ├── install.ps1        # PowerShell installer
│   └── registry.tsv.example
├── README.md
├── README_CN.md
└── LICENSE

~/.luo/                    # default LUO_HOME (shared between zsh & pwsh)
├── luo.zsh  or  luo.ps1
├── registry.tsv           # name / description / kind / payload
├── usage.tsv              # pick count per entry
├── alias                  # current alias name
└── scripts/               # managed scripts / symlinks
```

---

## License

MIT © [wuluoluoda](https://github.com/wuluoluoda)
