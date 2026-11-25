# ==========================================================================
# Brewfile — what mise can't provide: system libraries, build tools,
# tools without prebuilt macOS binaries, and GUI apps.
# CLI tools with prebuilt binaries live in home/.config/mise/config.toml.
# Usage: brew bundle --file Brewfile
# ==========================================================================

tap "libracoder/kiri"

# --- Core ---------------------------------------------------------------------
brew "git"
brew "curl"
brew "wget"
brew "gnupg"
brew "pinentry-mac"
brew "tmux"
brew "eza"            # no prebuilt macOS binary upstream
brew "trash"
brew "sqlite"

# --- Build toolchain ----------------------------------------------------------
brew "gcc"
brew "cmake"
brew "ninja"
brew "pkgconf"
brew "autoconf-archive"
brew "automake"

# --- yazi previews / media ----------------------------------------------------
brew "ffmpeg-full"
brew "imagemagick-full"
brew "poppler"
brew "sevenzip"
brew "chafa"

# --- Misc ---------------------------------------------------------------------
brew "cava"
brew "fontforge"
brew "forgejo-cli"
brew "mole"
brew "open-image-denoise"
brew "pgcli"
brew "postgresql@18"
brew "qemu"
brew "scrcpy"
brew "spotify_player"
brew "wimlib"

# --- GUI apps -----------------------------------------------------------------
cask "aerospace"
cask "azookey"
cask "betterdisplay", args: { adopt: true }  # installed by hand before
cask "codex"
cask "discord"
cask "figma"
cask "ghostty"
cask "kiri"
cask "linearmouse"
cask "neovide-app"
cask "notion"
cask "obs"
cask "spotify"
cask "stats"
cask "ardia", args: { adopt: true }          # installed by hand before
cask "font-lilex-nerd-font"
cask "font-symbols-only-nerd-font"
