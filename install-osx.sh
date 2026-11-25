#!/usr/bin/env bash
#
# macOS dev environment setup
#   ./install-osx.sh            interactive section picker
#   ./install-osx.sh -a         everything
#   ./install-osx.sh brew tools only the listed sections
#
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail
trap 'echo "[ERROR] line $LINENO" >&2' ERR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Bootstrap (always): Xcode CLT → Homebrew → mise (mise also provides gum)
# ---------------------------------------------------------------------------
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools…"
  xcode-select --install || true
  echo "Accept the system dialog, then press Enter when it finishes."
  read -r _
  xcode-select -p &>/dev/null || { echo "Xcode CLT not detected — aborting."; exit 1; }
fi
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ "$(uname -m)" == "arm64" ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Running via curl without a clone: fetch the repo first so lib.sh exists.
if [[ ! -f "$HERE/scripts/lib.sh" ]]; then
  HERE="$HOME/ghq/github.com/NaruseNia/dotfiles"
  [[ -d "$HERE" ]] || git clone https://github.com/NaruseNia/dotfiles.git "$HERE"
fi
# shellcheck source=scripts/lib.sh
source "$HERE/scripts/lib.sh"
ensure_mise

# ---------------------------------------------------------------------------
# macOS-only sections
# ---------------------------------------------------------------------------
run_brew() {
  spin "brew update…" brew update
  spin "brew bundle (CLI libs + apps)…" brew bundle --file "$DOTFILES_DIR/Brewfile" \
    && ok "Brewfile applied" || warn "some Brewfile entries failed — rerun: brew bundle --file $DOTFILES_DIR/Brewfile"
  brew link ffmpeg-full imagemagick-full -f --overwrite &>/dev/null || true
}

install_codex() {
  if brew list --cask codex &>/dev/null; then info "codex (already installed)"; return 0; fi
  spin "Installing codex…" brew install --cask codex && ok "codex installed"
}

run_identity() {
  local key="$HOME/.ssh/id_ed25519"
  if [[ -f "$key" ]]; then
    info "SSH key already at $key"
  else
    local email; email=$(gum input --placeholder "Email for SSH key")
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$email" -f "$key" -N "" >/dev/null
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add --apple-use-keychain "$key" 2>/dev/null || ssh-add "$key"
    pbcopy < "$key.pub"
    ok "SSH key generated (public key copied to clipboard)"
  fi

  gh auth status &>/dev/null || { warn "GitHub login…"; gh auth login -s admin:public_key; }
  gh auth status 2>&1 | grep -q admin:public_key || gh auth refresh -h github.com -s admin:public_key

  if [[ -f "$key.pub" ]] && ! gh ssh-key list 2>/dev/null | grep -q "$(awk '{print $2}' "$key.pub")"; then
    spin "Uploading SSH key to GitHub…" gh ssh-key add "$key.pub" -t "$(hostname)" \
      && ok "SSH key uploaded" || warn "upload manually: gh ssh-key add $key.pub"
  else
    info "SSH key already on GitHub"
  fi

  git -C "$DOTFILES_DIR" remote set-url origin git@github.com:NaruseNia/dotfiles.git
  ok "dotfiles remote switched to SSH"
}

run_defaults() {
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  mkdir -p "$HOME/Pictures/Screenshots"
  defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
  killall Finder SystemUIServer &>/dev/null || true
  ok "macOS defaults applied (some need logout)"
}

# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------
SECTIONS=(mise dotfiles brew tools ai identity nvim tmux zellij defaults)

section_title() {
  case "$1" in
    mise)     echo "mise" ;;
    dotfiles) echo "Dotfiles (mise dot)" ;;
    brew)     echo "Homebrew bundle" ;;
    tools)    echo "Runtimes & CLI tools (mise)" ;;
    ai)       echo "AI tools: claude · codex · agy" ;;
    identity) echo "SSH key · gh auth" ;;
    nvim)     echo "Neovim config" ;;
    tmux)     echo "tmux plugin manager" ;;
    zellij)   echo "zellij plugins" ;;
    defaults) echo "macOS defaults" ;;
  esac
}

usage() {
  echo "Usage: $(basename "$0") [-a | -h | section …]"
  echo
  for s in "${SECTIONS[@]}"; do printf "  %-9s %s\n" "$s" "$(section_title "$s")"; done
}

banner "macOS setup" "$(sw_vers -productName) $(sw_vers -productVersion)"
pick_sections "$@"
run_sections "${TO_RUN[@]}"
summary
