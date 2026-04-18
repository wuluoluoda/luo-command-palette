# Publishing Luo to GitHub (one-time)

Your local repo is ready under this folder (its own `.git` on `main`).

1. On GitHub: **New repository** → name **`luo`** → Public → **do not** add README / .gitignore / license (already in the tree).

2. In a terminal:

```bash
cd /path/to/luo   # this directory (the one containing install.sh)
git remote add origin https://github.com/wuluoluoda/luo.git
git branch -M main
git push -u origin main
```

3. Set the repository **About** description (optional, shown on GitHub):

> Luo — a command-line and script management tool for zsh on macOS

4. Verify the one-liner (after `main` exists on GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/luo/main/install.sh | bash
```

If your GitHub username is not `wuluoluoda`, replace it in `install.sh` (`GITHUB_RAW`), `README.md`, and `LICENSE` (copyright line), then commit and push again.
