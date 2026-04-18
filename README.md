# CmdRoster

**CmdRoster** is a small **command-line and script management** tool for **zsh on macOS**. Register shell snippets or scripts once, then pick them with **fzf** — the chosen command is placed on your **command line** ready to review and execute.

The interactive command is named **`luo`** (three letters, easy to type). Data lives under **`~/.luo/`** by default (`LUO_HOME`).

> 中文说明见 [README_CN.md](README_CN.md)

## Platform support

| Platform | Status |
|----------|--------|
| macOS | ✅ Full support |
| Windows (WSL 2) | ✅ Full support |
| Linux (native) | ✅ Full support |
| Windows (native PowerShell / CMD) | ❌ Not supported |

**Windows users**: install via **WSL 2** (Windows Subsystem for Linux). See the [WSL install guide](#windows-wsl-2) below.

## Requirements

| Tool | Install |
|------|---------|
| zsh | macOS built-in · Linux/WSL: `sudo apt-get install zsh` |
| [fzf](https://github.com/junegunn/fzf) | macOS: `brew install fzf` · Linux/WSL: `sudo apt-get install fzf` |

## Install

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/install.sh | bash
```

The installer auto-detects your OS and installs **fzf** via the right package manager if missing (`brew` on macOS, `apt-get` / `pacman` / `dnf` / `yum` on Linux/WSL).

### Clone and install

```bash
git clone https://github.com/wuluoluoda/cmdroster.git
cd cmdroster
./install.sh
```

Activate in the **current** terminal (new shells load it from `~/.zshrc` automatically):

```bash
source ~/.luo/luo.zsh
```

### Custom install directory

```bash
LUO_HOME=~/my-tools ./install.sh
```

If `LUO_HOME` is not the default `~/.luo`, the installer adds `export LUO_HOME=…` to `~/.zshrc`.

### Windows (WSL 2)

1. Install WSL 2 and a distro (Ubuntu recommended):

   ```powershell
   # in PowerShell (Admin)
   wsl --install
   ```

2. Open **Ubuntu** (or your distro) from Windows Terminal, then install zsh and run the one-liner:

   ```bash
   sudo apt-get update && sudo apt-get install -y zsh
   chsh -s $(which zsh)          # set zsh as default shell
   curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/install.sh | bash
   ```

3. Open a new **Windows Terminal** tab (with Ubuntu profile) — `luo` is ready.

## Quick start

```bash
luo add "caffeinate -di"            # register a shell command
luo add ./my-script.sh              # register a script (symlinked under ~/.luo/scripts/)
luo add -n wake "caffeinate -di"    # custom display name
luo help                            # open fuzzy picker; Enter puts the command on your line
luo alias pp                        # set "pp" as a short alias for luo help
pp                                  # same as luo help
```

## Commands

| Command | Description |
|---------|-------------|
| `luo help` | fzf picker (alphabetical); **Tab** narrows by name; **Enter** puts command on command line; **Fn+F2** toggles delete mode (green UI, **Enter** deletes); **Ctrl+N** / **Esc** quit |
| `luo add [options] …` | Register a command or script (see below) |
| `luo list` | Print the full registry (TSV with header) |
| `luo sync [-p]` | Merge unregistered files under `scripts/`; `-p` also prunes stale rows |
| `luo rm` / `luo remove` | Same as `luo help` but opens directly in delete mode |
| `luo alias [name]` | Set / view / clear a short alias for `luo help` (see below) |
| `luo home` | Print `LUO_HOME` |

### `luo add` options

| Option | Meaning |
|--------|---------|
| `-n <name>` | Display name (default: first word of command, or script basename) |
| `-d <desc>` | Description (scripts can embed `# luo:desc …` to set this automatically) |
| `-f` | Overwrite an existing entry with the same name |

**Path detection**: if the argument contains `/` or starts with `./` / `../` and resolves to a file → registered as **file** (symlink created under `~/.luo/scripts/`). Otherwise the whole string is stored as a **shell** command.

### `luo alias` — set a short alias for `luo help`

Tired of typing `luo help`? Pick any short name that doesn't conflict with system commands:

```bash
luo alias ql        # define "ql" as a shortcut for luo help
ql                  # opens the picker immediately

luo alias           # show the current alias
luo alias off       # remove the alias
```

The alias name is saved to `~/.luo/alias` and automatically restored every time `luo.zsh` is sourced (i.e., in every new terminal). Renaming automatically removes the old function.

> **Note**: if the name already exists as a system command, you will be warned before the alias is created.

### How `luo help` fills the command line

After you pick an entry, the command is written to the **ZLE line buffer** (`print -z`) inside a `precmd` hook — after fzf has fully exited and the terminal is restored — so it appears on your prompt ready to edit or run.

## Layout

```
~/.luo/
├── luo.zsh          # main logic (installed/updated by install.sh)
├── registry.tsv     # entry database (tab-separated UTF-8)
├── usage.tsv        # per-entry pick counts (triggers confirmation on delete if > 30)
├── alias            # one-line file storing the current alias name (if set)
└── scripts/         # symlinks to registered script files
```

Registry columns: `name`, `description`, `kind` (`shell` | `file`), `payload`.

## Tab completion

`luo.zsh` registers `_luo_cmd_complete` with `compdef`. Ensure **`compinit` runs before `source luo.zsh`** in `~/.zshrc` for subcommand completion to work.

## Uninstall

```bash
rm -rf ~/.luo
# Also remove the block in ~/.zshrc between:
# >>> luo script hub
# <<< luo script hub
```

## License

MIT — see [LICENSE](LICENSE).
