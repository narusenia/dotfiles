# dotfiles

Dev environment for macOS, Linux and Windows, built on [mise](https://mise.jdx.dev):

- **Dotfiles** — every file under `home/` is symlinked to the same path under `~`
  by `mise dot apply`.
- **CLI tools and runtimes** — one list in `home/.config/mise/config.toml`,
  installed by `mise install`. Prebuilt binaries via the `aqua:` backend, so the
  same list works on every OS.
- **Everything else** — Homebrew (`Brewfile`), the Linux package manager, winget,
  or Nix provides system libraries and GUI apps.

The mise config is itself one of the dotfiles, so the repo describes both the
files and the tools.

## Layout

```
home/                      → linked into ~ (mirror of $HOME)
  .config/mise/config.toml   tools, [dotfile_groups], global tasks
  .zshrc .zprofile .zshenv .gitconfig .tmux.conf …
Brewfile                   macOS: system libs, tools without macOS binaries, casks
scripts/lib.sh             UI + sections shared by the shell installers
install-osx.sh             macOS installer
install-linux.sh           Linux installer (apt / dnf / pacman / zypper, or -b for Linuxbrew)
install-windows.ps1        Windows installer (winget) — untested
install-nix.sh, nix/       Nix alternative (nix-darwin / home-manager)
```

The repo lives at `~/ghq/github.com/NaruseNia/dotfiles`. That path is written
once, as `dotfiles.root` in the mise config.

## Setup

```sh
git clone https://github.com/NaruseNia/dotfiles.git ~/ghq/github.com/NaruseNia/dotfiles
cd ~/ghq/github.com/NaruseNia/dotfiles

./install-osx.sh          # macOS: pick sections interactively
./install-osx.sh -a       # macOS: everything
./install-linux.sh -a     # Linux (add -b for Linuxbrew)
./install-nix.sh          # Nix path (see nix/ARCHITECTURE.md)
```

```powershell
# Windows (PowerShell)
git clone https://github.com/NaruseNia/dotfiles.git $HOME\ghq\github.com\NaruseNia\dotfiles
cd $HOME\ghq\github.com\NaruseNia\dotfiles
.\install-windows.ps1
```

Each installer bootstraps mise first and runs in sections, so any part can be
rerun alone, e.g. `./install-osx.sh dotfiles tools`. Existing real files that
would be replaced by a link are moved to `~/.dotfiles-backup/<timestamp>/`.

On Windows, `mise dot apply` copies files instead of linking them unless
Developer Mode is on. Copies don't follow the repo, so rerun
`mise run dot:sync` after pulling.

### Doing it by hand

```sh
curl https://mise.run | sh
mkdir -p ~/.config/mise
ln -s ~/ghq/github.com/NaruseNia/dotfiles/home/.config/mise/config.toml ~/.config/mise/config.toml
mise dot apply
mise install
```

## Day-to-day

Files in `~` are symlinks into the repo, so editing `~/.zshrc` edits the repo.
The global tasks below run from any directory (`mise tasks` lists them):

| Task | What it does |
|------|--------------|
| `mise run dot:status` | uncommitted changes + link status |
| `mise run dot:save "message"` | commit everything and push |
| `mise run dot:sync` | pull, relink, install newly added tools |
| `mise run dot:add <path>` | move a file into `home/` and link it back |
| `mise run dot:edit` | open the repo in `$EDITOR` |
| `mise run brew:check` | brew packages installed but missing from `Brewfile` |
| `mise run tools:up` | upgrade mise tools, drop unused versions |
| `mise run clean` | free disk space (brew, mise, npm, pnpm, uv caches) |

Adding a tool: `mise use -g aqua:owner/repo` writes it into the repo's config.
Prefer `aqua:` over the registry default, which may compile from source
(`cargo:`) or use an asdf plugin that doesn't work on Windows.

## Git identity

`home/.gitconfig` holds the shared settings and identity. Extra
machine-specific settings go in `~/.gitconfig.local`, which the committed file
includes and this repo never touches. It is included before `[user]`, so the
committed identity wins for keys set in both. Never run `git config --global` here: `~/.gitconfig`
is a link into the repo, so it would edit the committed file.
