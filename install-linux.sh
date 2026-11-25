#!/usr/bin/env bash
#
# Linux dev environment setup
#   ./install-linux.sh            interactive section picker (system package manager)
#   ./install-linux.sh -a -b      everything, Linuxbrew for system packages
#   ./install-linux.sh pkgs tools only the listed sections
#
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail
trap 'echo "[ERROR] line $LINENO" >&2' ERR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --brew / -b must be known before bootstrap
USE_BREW=0
_args=()
for a in "$@"; do
  case "$a" in
    -b|--brew) USE_BREW=1 ;;
    *)         _args+=("$a") ;;
  esac
done
set -- "${_args[@]+"${_args[@]}"}"

if   command -v pacman  &>/dev/null; then PM=pacman
elif command -v apt-get &>/dev/null; then PM=apt
elif command -v dnf     &>/dev/null; then PM=dnf
elif command -v zypper  &>/dev/null; then PM=zypper
else echo "No supported package manager found (pacman/apt/dnf/zypper)." >&2; exit 1
fi
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

pm_update() {
  case "$PM" in
    apt)    $SUDO apt-get update ;;
    dnf)    $SUDO dnf check-update || true ;;
    pacman) $SUDO pacman -Sy --noconfirm ;;
    zypper) $SUDO zypper --non-interactive refresh ;;
  esac
}

pm_is_installed() {
  local p="$1"
  case "$PM" in
    apt)    dpkg -s "$p" &>/dev/null ;;
    dnf)    rpm -q "$p" &>/dev/null ;;
    pacman) pacman -Qi "$p" &>/dev/null ;;
    zypper) rpm -q "$p" &>/dev/null ;;
  esac
}

pm_install_raw() {
  case "$PM" in
    apt)    $SUDO apt-get install -y "$@" ;;
    dnf)    $SUDO dnf install -y "$@" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$@" ;;
    zypper) $SUDO zypper --non-interactive install "$@" ;;
  esac
}

# ---------------------------------------------------------------------------
# Bootstrap: build tools + gum
# ---------------------------------------------------------------------------
# Ensure base build tools for things like cargo/go builds and downloads.
case "$PM" in
  apt)    pm_is_installed build-essential || pm_install_raw build-essential curl ca-certificates ;;
  dnf)    $SUDO dnf groupinstall -y "Development Tools" 2>/dev/null || true; pm_install_raw curl ca-certificates ;;
  pacman) pm_is_installed base-devel || pm_install_raw base-devel curl ;;
  zypper) $SUDO zypper --non-interactive install -t pattern devel_basis || true; pm_install_raw curl ;;
esac


# ---------------------------------------------------------------------------
# Bootstrap (always): build tools + git + curl → mise (mise also provides gum)
# ---------------------------------------------------------------------------
case "$PM" in
  apt)    pm_is_installed build-essential || pm_install_raw build-essential curl ca-certificates git ;;
  dnf)    $SUDO dnf groupinstall -y "Development Tools" 2>/dev/null || true; pm_install_raw curl ca-certificates git ;;
  pacman) pm_is_installed base-devel || pm_install_raw base-devel curl git ;;
  zypper) $SUDO zypper --non-interactive install -t pattern devel_basis || true; pm_install_raw curl git ;;
esac

install_linuxbrew() {
  command -v brew &>/dev/null && return 0
  # Linuxbrew prereqs
  case "$PM" in
    apt)    pm_install_raw build-essential procps file git ;;
    dnf)    pm_install_raw procps-ng file git ;;
    pacman) pm_install_raw base-devel procps-ng file git ;;
    zypper) pm_install_raw procps file git ;;
  esac
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # shellcheck disable=SC2016
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}

[[ "$USE_BREW" == "1" ]] && install_linuxbrew
[[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

if [[ ! -f "$HERE/scripts/lib.sh" ]]; then
  HERE="$HOME/ghq/github.com/NaruseNia/dotfiles"
  [[ -d "$HERE" ]] || git clone https://github.com/NaruseNia/dotfiles.git "$HERE"
fi
# shellcheck source=scripts/lib.sh
source "$HERE/scripts/lib.sh"
ensure_mise

# ---------------------------------------------------------------------------
# Package helpers
# ---------------------------------------------------------------------------
# Generic name → distro-specific name lookup
pkg_name() {
  # Usage: pkg_name <generic>  → prints the correct pkg name for current PM (or '-' to skip)
  local g="$1"
  case "$g:$PM" in
    # Differences only — anything not listed falls through to $g
    bat:apt)             echo bat ;;             # on older Ubuntu it's 'batcat'; accept risk
    fd:apt)              echo fd-find ;;
    fd:dnf)              echo fd-find ;;
    sqlite:apt)          echo sqlite3 ;;
    sqlite:dnf)          echo sqlite ;;
    sqlite:zypper)       echo sqlite3 ;;
    gh:apt)              echo gh ;;              # requires GitHub CLI apt repo on some versions
    gh:dnf)              echo gh ;;
    gh:pacman)           echo github-cli ;;
    sevenzip:apt)        echo p7zip-full ;;
    sevenzip:dnf)        echo p7zip ;;
    sevenzip:zypper)     echo p7zip ;;
    sevenzip:pacman)     echo p7zip ;;
    ffmpeg-full:*)       echo ffmpeg ;;
    imagemagick-full:*)  echo imagemagick ;;
    poppler:apt)         echo poppler-utils ;;
    poppler:dnf)         echo poppler-utils ;;
    poppler:zypper)      echo poppler-tools ;;
    poppler:pacman)      echo poppler ;;
    qemu:apt)            echo qemu-system-x86 ;;
    qemu:pacman)         echo qemu-full ;;
    resvg:*)             echo resvg ;;           # may not exist on some distros
    pinentry-mac:*)      echo - ;;               # skip on Linux
    gcc:apt)             echo - ;;               # already via build-essential
    gcc:pacman)          echo - ;;               # already via base-devel
    *) echo "$g" ;;
  esac
}

# Map generic names to brew formula names (most match 1:1).
brew_name() {
  case "$1" in
    sevenzip)         echo sevenzip ;;
    ffmpeg-full)      echo ffmpeg ;;
    imagemagick-full) echo imagemagick ;;
    pinentry-mac)     echo - ;;
    gcc)              echo - ;;
    xclip|wl-clipboard) echo - ;;   # no-op under brew (display server integration via host)
    *) echo "$1" ;;
  esac
}

brew_install() {
  local pkg="$1"
  [[ "$pkg" == "-" ]] && return 0
  if brew list --formula "$pkg" &>/dev/null; then
    info "$pkg (already installed via brew)"
    return 0
  fi
  if spin "Installing $pkg (brew)..." brew install "$pkg"; then
    ok "$pkg installed (brew)"
  else
    fail "$pkg failed — skipping"
  fi
  return 0
}

# Install a single-binary release from a GitHub repo tarball.
# Usage: github_bin_install <bin> <repo> <asset_regex> [archive_inner_path]
github_bin_install() {
  local bin="$1" repo="$2" regex="$3" inner="${4:-}"
  command -v "$bin" &>/dev/null && { info "$bin (already on PATH)"; return 0; }
  local arch os; arch=$(uname -m); os=linux
  local tmp; tmp=$(mktemp -d)
  local url
  url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -Eo "\"browser_download_url\":\s*\"[^\"]*$regex[^\"]*\"" \
        | head -1 | sed -E 's/.*"(https[^"]+)".*/\1/')
  if [[ -z "$url" ]]; then
    fail "$bin: no matching release asset found in $repo (regex: $regex)"
    rm -rf "$tmp"; return 1
  fi
  if ! spin "Downloading $bin from $repo..." curl -fsSL -o "$tmp/pkg" "$url"; then
    rm -rf "$tmp"; return 1
  fi
  mkdir -p "$HOME/.local/bin"
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf "$tmp/pkg" -C "$tmp" ;;
    *.zip)          unzip -qo "$tmp/pkg" -d "$tmp" ;;
    *)              cp "$tmp/pkg" "$tmp/$bin"; chmod +x "$tmp/$bin" ;;
  esac
  local found
  if [[ -n "$inner" ]]; then
    found="$tmp/$inner"
  else
    found=$(find "$tmp" -type f -name "$bin" -perm -u+x 2>/dev/null | head -1)
    [[ -z "$found" ]] && found=$(find "$tmp" -type f -name "$bin" 2>/dev/null | head -1)
  fi
  if [[ -z "$found" || ! -f "$found" ]]; then
    fail "$bin: binary not found in downloaded archive"
    rm -rf "$tmp"; return 1
  fi
  install -m 0755 "$found" "$HOME/.local/bin/$bin"
  ok "$bin installed to ~/.local/bin (GitHub release)"
  rm -rf "$tmp"
}

pkg_install() {
  local generic="$1"

  # Linuxbrew mode
  if [[ "$USE_BREW" == "1" ]]; then
    local bn; bn=$(brew_name "$generic")
    [[ "$bn" == "-" ]] && { info "$generic (not needed under brew)"; return 0; }
    brew_install "$bn"
    return 0
  fi

  # System package manager
  local resolved; resolved=$(pkg_name "$generic")
  [[ "$resolved" == "-" ]] && { info "$generic (skipped on $PM)"; return 0; }
  if pm_is_installed "$resolved"; then
    info "$resolved (already installed)"
    return 0
  fi
  if spin "Installing $resolved..." bash -c "$(declare -f pm_install_raw); PM=$PM; SUDO='$SUDO'; pm_install_raw '$resolved'"; then
    ok "$resolved installed"
    return 0
  fi

  # PM install failed — try GitHub release fallback for select tools
  case "$generic" in
    eza)       github_bin_install eza     eza-community/eza     "eza_x86_64-unknown-linux-gnu\\.tar\\.gz" ;;
    lazygit)   github_bin_install lazygit jesseduffield/lazygit "lazygit_.*_Linux_x86_64\\.tar\\.gz" ;;
    git-delta) github_bin_install delta   dandavison/delta      "delta-.*-x86_64-unknown-linux-gnu\\.tar\\.gz" ;;
    *)         fail "$resolved failed — skipping" ;;
  esac
  return 0
}

# Cross-platform clipboard copy
clip_copy() {
  if   command -v wl-copy &>/dev/null; then wl-copy
  elif command -v xclip   &>/dev/null; then xclip -selection clipboard
  elif command -v xsel    &>/dev/null; then xsel --clipboard --input
  else cat; return 1
  fi
}


# ---------------------------------------------------------------------------
# Linux-only sections
# ---------------------------------------------------------------------------
# System packages only; CLI tools with prebuilt binaries come from mise (tools section).
run_pkgs() {
  spin "Updating package index…" bash -c "$(declare -f pm_update); PM=$PM; SUDO='$SUDO'; pm_update"
  local pkgs=(
    git curl wget tmux eza gcc sqlite unzip
    xclip wl-clipboard qemu
    ffmpeg-full sevenzip poppler imagemagick-full
  )
  for p in "${pkgs[@]}"; do pkg_install "$p"; done
}

run_apps() {

  # vivaldi
  case "$PM" in
    apt)
      if ! pm_is_installed vivaldi-stable; then
        $SUDO install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://repo.vivaldi.com/archive/linux_signing_key.pub | \
          $SUDO gpg --dearmor -o /etc/apt/keyrings/vivaldi.gpg
        echo "deb [signed-by=/etc/apt/keyrings/vivaldi.gpg] https://repo.vivaldi.com/archive/deb/ stable main" \
          | $SUDO tee /etc/apt/sources.list.d/vivaldi.list >/dev/null
        $SUDO apt-get update
        pkg_install vivaldi-stable
      else info "vivaldi (already installed)"; fi
      ;;
    dnf)    pkg_install "https://downloads.vivaldi.com/stable/vivaldi-stable.x86_64.rpm" ;;
    pacman)
      if command -v yay &>/dev/null; then
        spin "Installing vivaldi via yay (AUR)..." yay -S --noconfirm vivaldi && ok "vivaldi installed"
      elif command -v paru &>/dev/null; then
        spin "Installing vivaldi via paru (AUR)..." paru -S --noconfirm vivaldi && ok "vivaldi installed"
      else
        warn "vivaldi → AUR helper not found. Install yay/paru, then: yay -S vivaldi"
      fi
      ;;
    zypper) pkg_install "https://downloads.vivaldi.com/stable/vivaldi-stable.x86_64.rpm" ;;
  esac

  # ghostty
  case "$PM" in
    pacman) pkg_install ghostty ;;
    *)      warn "ghostty → no standard package. See https://ghostty.org/docs/install/binary" ;;
  esac

  # kiri (Docker-compatible container runtime) — .deb / .rpm from GitHub releases
  if command -v kiri &>/dev/null; then
    info "kiri (already installed)"
  else
    local arch ext pat url tmp
    arch=$(uname -m)
    case "$PM" in
      apt)        ext=deb; [[ $arch == x86_64 ]] && pat="kiri_[0-9.]*_amd64.deb" || pat="kiri_[0-9.]*_arm64.deb" ;;
      dnf|zypper) ext=rpm; pat="kiri-[0-9.]*-1.${arch}.rpm" ;;
      *)          ext="" ;;
    esac
    if [[ -n "$ext" ]]; then
      url=$(curl -fsSL https://api.github.com/repos/libracoder/kiri/releases/latest \
            | grep -Eo "https://[^\"]*/${pat}" | head -1)
      tmp=$(mktemp -d)
      if [[ -n "$url" ]] && spin "Downloading kiri…" curl -fsSL -o "$tmp/kiri.$ext" "$url" \
         && spin "Installing kiri…" bash -c "$(declare -f pm_install_raw); PM=$PM; SUDO='$SUDO'; pm_install_raw '$tmp/kiri.$ext'"; then
        ok "kiri installed"
      else
        fail "kiri install failed — see https://runkiri.com/releases/"
      fi
      rm -rf "$tmp"
    else
      warn "kiri → no package for $PM; see https://runkiri.com/releases/"
    fi
  fi

  # Nerd Font (Lilex + SymbolsOnly) — GitHub release
  local fonts_dir="$HOME/.local/share/fonts"
  mkdir -p "$fonts_dir"
  install_nerd_font() {
    local font="$1"
    if compgen -G "$fonts_dir/${font}*" >/dev/null; then
      info "$font Nerd Font (already installed)"
      return 0
    fi
    local tmp; tmp=$(mktemp -d)
    if spin "Fetching $font Nerd Font..." \
      curl -fsSL -o "$tmp/$font.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip"; then
      unzip -qo "$tmp/$font.zip" -d "$fonts_dir/$font" >/dev/null || true
      ok "$font Nerd Font installed"
    else
      fail "$font Nerd Font fetch failed"
    fi
    rm -rf "$tmp"
  }
  pm_is_installed unzip || pkg_install unzip
  install_nerd_font Lilex
  install_nerd_font NerdFontsSymbolsOnly
  command -v fc-cache &>/dev/null && fc-cache -f "$fonts_dir" >/dev/null 2>&1 || true
}

install_codex() {
  # no Linux cask: npm package through mise-managed node
  if command -v codex &>/dev/null; then info "codex (already installed)"; return 0; fi
  spin "Installing codex (npm)…" mise x node -- npm install -g @openai/codex && ok "codex installed" \
    || fail "codex failed — run: npm install -g @openai/codex"
}

run_identity() {
  local ssh_key="$HOME/.ssh/id_ed25519"
  if [[ -f "$ssh_key" ]]; then
    info "SSH key already exists at $ssh_key"
  else
    local email
    email=$(gum input --placeholder "Email for SSH key (e.g. you@example.com)")
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$email" -f "$ssh_key" -N ""
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$ssh_key"
    if clip_copy < "${ssh_key}.pub"; then
      ok "SSH key generated (public key copied to clipboard)"
    else
      warn "No clipboard tool found — public key:"
      cat "${ssh_key}.pub"
    fi
  fi

  if gh auth status &>/dev/null; then
    info "gh already authenticated"
  else
    warn "Launching interactive GitHub login (requesting admin:public_key scope)..."
    gh auth login -s admin:public_key
  fi

  if gh auth status 2>&1 | grep -q "admin:public_key"; then :; else
    warn "Refreshing gh token to add 'admin:public_key' scope..."
    gh auth refresh -h github.com -s admin:public_key
  fi

  if gh auth status &>/dev/null && [[ -f "${ssh_key}.pub" ]]; then
    local key_content
    key_content=$(awk '{print $2}' "${ssh_key}.pub")
    if gh ssh-key list 2>/dev/null | grep -q "$key_content"; then
      info "SSH key already registered on GitHub"
    else
      if spin "Uploading SSH key to GitHub..." gh ssh-key add "${ssh_key}.pub" -t "$(hostname)"; then
        ok "SSH key uploaded to GitHub"
      else
        fail "SSH key upload failed — upload manually: gh ssh-key add ${ssh_key}.pub"
      fi
    fi
  fi

  # ~/.gitconfig is a link into the repo, so never write to it with --global
  git -C "$DOTFILES_DIR" remote set-url origin git@github.com:NaruseNia/dotfiles.git
  ok "dotfiles remote switched to SSH"
}


run_defaults() {
  mkdir -p "$HOME/Pictures/Screenshots"
  ok "~/Pictures/Screenshots ensured"
}

# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------
SECTIONS=(mise dotfiles pkgs tools apps ai identity nvim tmux zellij defaults)

section_title() {
  case "$1" in
    mise)     echo "mise" ;;
    dotfiles) echo "Dotfiles (mise dot)" ;;
    pkgs)     echo "System packages ($PM$([[ $USE_BREW == 1 ]] && echo ' + brew'))" ;;
    tools)    echo "Runtimes & CLI tools (mise)" ;;
    apps)     echo "GUI apps · kiri · fonts" ;;
    ai)       echo "AI tools: claude · codex · agy" ;;
    identity) echo "SSH key · gh auth" ;;
    nvim)     echo "Neovim config" ;;
    tmux)     echo "tmux plugin manager" ;;
    zellij)   echo "zellij plugins" ;;
    defaults) echo "Linux defaults" ;;
  esac
}

usage() {
  echo "Usage: $(basename "$0") [-b] [-a | -h | section …]"
  echo "  -b, --brew  use Linuxbrew instead of the system package manager"
  echo
  for s in "${SECTIONS[@]}"; do printf "  %-9s %s\n" "$s" "$(section_title "$s")"; done
}

banner "Linux setup" "$( . /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -sr)"
pick_sections "$@"
run_sections "${TO_RUN[@]}"
summary
