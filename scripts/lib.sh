# shellcheck shell=bash
# Shared UI and sections for install-osx.sh / install-linux.sh.
# Sourced, not executed. Expects bash 4+ features only where noted.

DOTFILES_REPO="https://github.com/NaruseNia/dotfiles.git"
DOTFILES_DIR="$HOME/ghq/github.com/NaruseNia/dotfiles"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# ---------------------------------------------------------------------------
# Palette & UI
# ---------------------------------------------------------------------------
C_ACCENT=212   # pink
C_SUB=99       # violet
C_OK=42        # green
C_WARN=214     # orange
C_ERR=203      # red
C_DIM=244      # gray

# gum comes from mise, so the UI works before Homebrew or a package manager.
gum() {
  # type -P: look for a binary only (command -v would find this function)
  local bin; bin=$(type -P gum || true)
  if [[ -n "$bin" && "$bin" != *"/shims/"* ]]; then
    "$bin" "$@"
  else
    mise x aqua:charmbracelet/gum@latest -- gum "$@"
  fi
}

ensure_mise() {
  command -v mise &>/dev/null && return 0
  echo "  › installing mise (needed for the installer UI)…"
  curl -fsSL https://mise.run | sh >/dev/null
  command -v mise &>/dev/null || { echo "mise install failed — aborting." >&2; exit 1; }
}

info() { gum style --foreground "$C_DIM"  "  · $*"; }
ok()   { gum style --foreground "$C_OK"   "  ✓ $*"; }
warn() { gum style --foreground "$C_WARN" "  ! $*"; }
fail() { gum style --foreground "$C_ERR"  "  ✗ $*"; }

spin() { gum spin --show-error --spinner minidot --title "  $1" -- "${@:2}"; }

banner() {
  local title="$1" os="$2"
  echo
  gum style --foreground "$C_ACCENT" --bold \
'    ██████╗  ██████╗ ████████╗███████╗' \
'    ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝' \
'    ██║  ██║██║   ██║   ██║   ███████╗' \
'    ██║  ██║██║   ██║   ██║   ╚════██║' \
'    ██████╔╝╚██████╔╝   ██║   ███████║' \
'    ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝'
  gum join --horizontal \
    "$(gum style --foreground 0 --background "$C_ACCENT" --bold --padding "0 1" "$title")" \
    "$(gum style --foreground "$C_DIM" --padding "0 1" "$os · $(whoami)@$(hostname -s) · $(date +%Y-%m-%d)")"
  echo
}

# section <index> <total> <title>
section() {
  local idx="$1" total="$2" title="$3"
  local bar; bar=$(printf '━%.0s' $(seq 1 $((44 - ${#title}))))
  echo
  gum join --horizontal \
    "$(gum style --foreground "$C_SUB" --bold "━━ [$idx/$total] ")" \
    "$(gum style --foreground 255 --bold "$title ")" \
    "$(gum style --foreground "$C_SUB" "$bar")"
}

# remote_install <name> <check-cmd> <url> [shell [args…]]
remote_install() {
  local name="$1" check="$2" url="$3"; shift 3
  local sh=("${@:-sh}")
  if command -v "$check" &>/dev/null; then info "$name (already installed)"; return 0; fi
  if spin "Installing $name…" bash -c 'curl -fsSL "$0" | "${@}"' "$url" "${sh[@]}"; then
    ok "$name installed"
  else
    fail "$name failed — skipping"
  fi
}

# ---------------------------------------------------------------------------
# Runner: executes sections with a counter and records status + duration
# ---------------------------------------------------------------------------
declare -a RESULT_ROWS=()

run_sections() {
  local total=$# i=0 s start dur status
  for s in "$@"; do
    i=$((i + 1))
    section "$i" "$total" "$(section_title "$s")"
    start=$SECONDS
    if "run_$s"; then status="✓"; else status="✗"; fi
    dur=$((SECONDS - start))
    RESULT_ROWS+=("$status,$s,${dur}s")
  done
}

summary() {
  echo
  gum style --border double --border-foreground "$C_OK" --foreground "$C_OK" \
    --bold --align center --padding "0 4" --margin "1 2" "✓  All done"
  gum style --foreground "$C_SUB" --bold "  Sections"
  printf '%s\n' "status,section,time" "${RESULT_ROWS[@]}" | gum table --print --border rounded \
    --border.foreground "$C_DIM" --separator ","
  echo
  gum style --foreground "$C_SUB" --bold "  Tools"
  {
    echo "tool,version"
    local t v
    for t in mise git gh nvim tmux zellij node python go rustc zig yazi claude codex agy; do
      command -v "$t" &>/dev/null || continue
      case "$t" in
        tmux)   v=$(tmux -V 2>/dev/null) ;;
        go|zig) v=$("$t" version 2>/dev/null | head -1) ;;
        *)      v=$("$t" --version 2>/dev/null | head -1) ;;
      esac
      v=${v//,/ }
      echo "$t,${v:-installed}"
    done
  } | gum table --print --border rounded --border.foreground "$C_DIM" --separator ","
  echo
  gum style --border rounded --border-foreground "$C_WARN" --foreground "$C_WARN" \
    --padding "0 2" --margin "0 2" \
    "dotfiles  $DOTFILES_DIR" \
    "edit      edit files in home/, then commit; new files: mise dot add <path>" \
    "" \
    "Restart your terminal (or exec \$SHELL -l) to load the new shell config."
}

# ---------------------------------------------------------------------------
# Shared sections
# ---------------------------------------------------------------------------
run_mise() {
  remote_install mise mise https://mise.run
}

# Clone the repo, back up real files that would be replaced, then link
# everything under home/ into ~ with `mise dot apply`.
run_dotfiles() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    info "repo already at $DOTFILES_DIR"
  else
    spin "Cloning dotfiles…" git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || { fail "clone failed"; return 1; }
    ok "cloned to $DOTFILES_DIR"
  fi

  local backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)" moved=0 f t
  while IFS= read -r f; do
    t="$HOME/${f#"$DOTFILES_DIR/home/"}"
    if [[ -e "$t" && ! -L "$t" ]]; then
      mkdir -p "$backup/$(dirname "${t#"$HOME/"}")"
      mv "$t" "$backup/${t#"$HOME/"}"
      moved=$((moved + 1))
    fi
  done < <(find "$DOTFILES_DIR/home" -type f ! -name .DS_Store)
  [[ $moved -gt 0 ]] && warn "backed up $moved existing file(s) to $backup"

  # mise reads [dotfiles] from its global config, which itself lives in the repo
  mkdir -p "$HOME/.config/mise"
  ln -sfn "$DOTFILES_DIR/home/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
  spin "mise dot apply…" mise dot apply --force && ok "dotfiles linked"
}

run_tools() {
  spin "mise install (runtimes + CLI tools)…" mise install --yes && ok "all mise tools installed"
}

run_ai() {
  remote_install claude claude https://claude.ai/install.sh bash
  remote_install agy agy https://antigravity.google/cli/install.sh bash -s -- --skip-path
  install_codex
}

# Terminal fonts (ghostty: Ioskeley Mono Term + Obel Mono italic)
FONT_DIR="$HOME/Library/Fonts"
[[ "$(uname -s)" == Linux ]] && FONT_DIR="$HOME/.local/share/fonts"

# install_font <label> <file-glob already installed> <zip url> <path pattern inside zip>
install_font() {
  local label="$1" check="$2" url="$3" pattern="$4" tmp
  if compgen -G "$FONT_DIR/$check" >/dev/null; then info "$label (already installed)"; return 0; fi
  tmp=$(mktemp -d)
  if spin "Downloading $label…" curl -fsSL -o "$tmp/font.zip" "$url"; then
    unzip -qo "$tmp/font.zip" -d "$tmp/x"
    mkdir -p "$FONT_DIR"
    find "$tmp/x" -path "$pattern" -name '*.ttf' -exec cp {} "$FONT_DIR/" \;
    ok "$label installed"
  else
    fail "$label download failed"
  fi
  rm -rf "$tmp"
}

run_fonts() {
  install_font "Ioskeley Mono Term" "IoskeleyMonoTerm-*.ttf" \
    https://github.com/ahatem/IoskeleyMono/releases/latest/download/IoskeleyMono-Term.zip "*/Normal/Hinted/*"
  # shortcut: Obel Mono has no "latest" URL, pinned to 1.004; bump when a new version ships
  install_font "Obel Mono" "ObelMono-*.ttf" \
    https://typographic.systems/download/ObelMono-1.004-ttf.zip "*/static/*"
  if command -v fc-cache &>/dev/null; then fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true; fi
}

run_nvim() {
  local dir="$HOME/.config/nvim"
  if [[ -d "$dir" ]]; then
    info "nvim config already at $dir"
  else
    spin "Cloning nvim config…" git clone https://github.com/NaruseNia/nvim.git "$dir" && ok "nvim config cloned"
  fi
  spin "Lazy sync…" nvim --headless "+Lazy! sync" +qa && ok "neovim plugins synced"
}

run_tmux() {
  local dir="$HOME/.tmux/plugins/tpm"
  if [[ -d "$dir" ]]; then info "tpm already installed"; return 0; fi
  spin "Cloning tpm…" git clone https://github.com/tmux-plugins/tpm "$dir" \
    && ok "tpm installed (prefix + I inside tmux to fetch plugins)"
}

run_zellij() {
  local wasm="$HOME/.config/zellij/plugins/zjstatus.wasm"
  mkdir -p "$(dirname "$wasm")"
  if [[ -f "$wasm" ]]; then info "zjstatus.wasm already present"; return 0; fi
  spin "Downloading zjstatus.wasm…" curl -fSL -o "$wasm" \
    https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm && ok "zjstatus.wasm downloaded"
}

# ---------------------------------------------------------------------------
# CLI parsing shared by both installers (SECTIONS and section_title defined by caller)
# ---------------------------------------------------------------------------
pick_sections() {
  # usage: pick_sections "$@"  → fills TO_RUN
  TO_RUN=()
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -a|--all)  TO_RUN=("${SECTIONS[@]}"); return ;;
    "")        ;;
    *)
      local arg x found
      for arg in "$@"; do
        found=0
        for x in "${SECTIONS[@]}"; do [[ "$x" == "$arg" ]] && found=1; done
        [[ $found == 1 ]] || { echo "Unknown section: $arg" >&2; usage; exit 1; }
        TO_RUN+=("$arg")
      done
      return ;;
  esac
  local selected
  selected=$(printf '%s\n' "${SECTIONS[@]}" | gum choose --no-limit --height 16 \
    --header "Select sections (space = toggle, enter = run)" \
    --cursor.foreground "$C_ACCENT" --selected.foreground "$C_ACCENT" \
    --selected "$(IFS=,; echo "${SECTIONS[*]}")")
  [[ -z "$selected" ]] && { info "Nothing selected."; exit 0; }
  while IFS= read -r line; do TO_RUN+=("$line"); done <<< "$selected"
}
