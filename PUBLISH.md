# Publishing luo-command-palette to GitHub

Public repo name: **`luo-command-palette`**. The zsh command stays **`luo`**.

Your local repo is ready under this folder (its own `.git` on `main`).

1. On GitHub: **New repository** or **Rename repository** → name **`luo-command-palette`** → Public → **do not** add README / .gitignore / license if creating a new repo (already in the tree).

2. In a terminal:

```bash
cd /path/to/luo-command-palette   # this directory (contains install.sh)
git remote set-url origin git@github.com:wuluoluoda/luo-command-palette.git
# If there is no origin yet, use:
# git remote add origin git@github.com:wuluoluoda/luo-command-palette.git
git branch -M main
git push -u origin main
```

3. Set the repository **About** description (optional):

> luo — a tiny command palette for your shell

4. Verify the one-liner (after `main` exists on GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/luo-command-palette/main/install.sh | bash
```

If your GitHub username is not `wuluoluoda`, replace it in `install.sh` (`GITHUB_RAW`), `README.md`, and `LICENSE` (copyright line), then commit and push again.

**If you already pushed to `wuluoluoda/cmdroster` or `wuluoluoda/luo`:** rename the repository to `luo-command-palette` or create the new repo, change `git remote` to the new URL, and push. You can archive the old repo when ready.
