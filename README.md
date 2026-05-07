# CmdRoster

**CmdRoster** is a small **command-line and script management** tool for **zsh on macOS**. Register shell snippets or scripts once, then pick them with **fzf** — the chosen command is placed on your **command line** ready to review and execute.

The interactive command is named **`luo`** (three letters, easy to type). Data lives under **`~/.luo/`** by default (`LUO_HOME`).

> 中文说明见 [README_CN.md](README_CN.md)

## Requirements

| Tool | Install |
|------|---------|
| zsh | Built into macOS |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` |

## Install

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/install.sh | bash
```

The installer detects missing **fzf** and offers to install it via Homebrew.

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

## Quick start

```bash
luo add "caffeinate -di"            # register a shell command
luo add ./my-script.sh              # register a script (symlinked under ~/.luo/scripts/)
luo add -n wake "caffeinate -di"    # custom display name
luo add                             # paste a multi-line command, then press Ctrl-D
luo add cd app                      # or put the first line after add, paste the rest, then press Ctrl-D
pbpaste | luo add -                 # or import a multi-line command from the clipboard
luo help                            # built-in subcommand list (same idea as --help)
luo cmd                             # open fuzzy picker over saved entries; Enter puts the command on your line
luo alias pp                        # set "pp" as a short alias for luo cmd
pp                                  # same as luo cmd
```

## Commands

**Note:** `luo help` is **built-in usage** (Unix-style). The fzf registry picker is **`luo cmd`** (synonym: `luo pick`). If you used an older layout where `luo help` opened fzf, switch those invocations to `luo cmd`.

| Command | Description |
|---------|-------------|
| `luo` / `luo help` / `luo usage` / `luo commands` / `luo -h` / `--help` | Print **this tool’s built-in subcommands** |
| `luo cmd` | fzf picker over **your saved entries** (alphabetical); **Tab** narrows by name; **Enter** puts command on command line; **Fn+F2** toggles delete mode (green UI, **Enter** deletes); **Ctrl+N** / **Esc** quit |
| `luo pick` | Same as `luo cmd` |
| `luo add [options] …` | Register a command or script (see below) |
| `luo list` | Print the full registry (TSV with header) |
| `luo sync [-p]` | Merge unregistered files under `scripts/`; `-p` also prunes stale rows |
| `luo rm` / `luo remove` | Same as `luo cmd` but opens directly in delete mode |
| `luo alias [name]` | Set / view / clear a short alias for `luo cmd` (see below) |
| `luo home` | Print `LUO_HOME` |

### `luo add` options

| Option | Meaning |
|--------|---------|
| `-n <name>` | Display name (default: compact name like `cd-app` or `npm-dev`; duplicate names get `-2`) |
| `-d <desc>` | Description (scripts can embed `# luo:desc …` to set this automatically) |
| `-f` | Overwrite an existing entry with the same name |

**Path detection**: if the argument contains `/` or starts with `./` / `../` and resolves to a file → registered as **file** (symlink created under `~/.luo/scripts/`). Otherwise the whole string is stored as a **shell** command.

Multi-line shell commands can be pasted directly, and the first line may be placed after `luo add`; in that form `luo add` keeps reading following lines until you press `Ctrl-D`, so they are saved instead of being executed by the shell. You can also read from standard input with the single `-` argument, so you do not need to type `\n` escapes. The default name stays compact: `cd app` becomes `cd-app`, `npm run dev` becomes `npm-dev`, and duplicate names get `-2`, `-3`, and so on. Use `-n <name>` only when you want a custom display name. They are stored safely as one registry row. When selected in `luo cmd`, they are restored as real multi-line text in the command line.

### `luo alias` — set a short alias for `luo cmd`

Tired of typing `luo cmd`? Pick any short name that doesn't conflict with system commands:

```bash
luo alias ql        # define "ql" as a shortcut for luo cmd
ql                  # opens the picker immediately

luo alias           # show the current alias
luo alias off       # remove the alias
```

The alias name is saved to `~/.luo/alias` and automatically restored every time `luo.zsh` is sourced (i.e., in every new terminal). Renaming automatically removes the old function.

> **Note**: if the name already exists as a system command, you will be warned before the alias is created.

### How `luo cmd` fills the command line

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

Registry columns: `name`, `description`, `kind` (`shell` | `file`), `payload`. Newly written fields escape backslashes, tabs, and newlines as needed so each entry stays on one physical line.

## Tab completion

`luo.zsh` registers `_luo_cmd_complete` with `compdef`. Ensure **`compinit` runs before `source luo.zsh`** in `~/.zshrc` for subcommand completion to work.

## Uninstall

```bash
./install.sh --uninstall
```

This removes `~/.luo/` and the luo block from `~/.zshrc`. Open a new terminal or run `exec zsh` to finish.

## License

MIT — see [LICENSE](LICENSE).
