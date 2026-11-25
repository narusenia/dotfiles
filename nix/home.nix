{ pkgs, lib, username, fullName, email, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux  = pkgs.stdenv.isLinux;
in
{
  home.username = username;
  home.homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";
  home.stateVersion = "24.11";

  # ---------------------------------------------------------------------
  # Packages: only what mise can't provide (system libs, tools without
  # prebuilt binaries). CLI tools and runtimes come from mise, declared in
  # home/.config/mise/config.toml, so every setup path shares one list.
  # ---------------------------------------------------------------------
  home.packages = with pkgs; [
    git curl wget gnupg tmux eza sqlite
    qemu
    # yazi preview dependencies
    ffmpeg p7zip poppler imagemagick
    mise
  ]
  ++ lib.optionals isDarwin [
    pinentry_mac
  ]
  ++ lib.optionals isLinux [
    xclip
    wl-clipboard
  ];

  # ---------------------------------------------------------------------
  # Programs — declarative shell/tool configs.
  # NOTE: these generate files under ~/ and ~/.config/*. Dotfiles are
  #       symlinked by `mise dot apply` (see below), and home-manager refuses
  #       to overwrite files it did not create, so keep these blocks off for
  #       any target that lives in the repo's home/ directory.
  # ---------------------------------------------------------------------
  # Git (include-file pattern):
  # The repo's ~/.gitconfig (linked by mise dot) sources this file via
  # `[include] path = ~/.config/git/nix.inc`. Portable defaults live here;
  # identity stays in the repo's .gitconfig. Settings in that file that appear AFTER
  # the include directive take precedence over anything here.
  xdg.configFile."git/nix.inc".text = ''
    [init]
        defaultBranch = main
    [pull]
        rebase = true
    [core]
        pager = delta
    [interactive]
        diffFilter = delta --color-only
    [delta]
        navigate = true
        dark = true
    [merge]
        conflictstyle = zdiff3
  '';

  # Disabled: the user's ~/.config/gh/config.yml already exists (from a
  # prior `gh auth login`) and home-manager refuses to overwrite files
  # it did not create. Replacing it would also nuke the auth token.
  # Re-enable only on a fresh machine where gh has not been used yet.
  # programs.gh = {
  #   enable = true;
  #   settings.git_protocol = "ssh";
  # };

  # Shell integrations — keep disabled: .zshrc / .zeno_zsh come from the repo.
  # programs.fzf.enable = true;
  # programs.zoxide.enable = true;
  # programs.bat.enable = true;

  # ---------------------------------------------------------------------
  # Dotfiles + tools through mise
  #
  # Same flow as install-osx.sh / install-linux.sh: clone the repo, point
  # mise's global config at the repo copy, link home/ into ~ with
  # `mise dot apply`, then install every tool the config declares.
  # ---------------------------------------------------------------------
  home.activation.miseDotfiles = lib.hm.dag.entryAfter [ "installPackages" "writeBoundary" ] ''
    repo="$HOME/ghq/github.com/NaruseNia/dotfiles"
    if [ ! -d "$repo/.git" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/NaruseNia/dotfiles.git "$repo"
    fi
    $DRY_RUN_CMD mkdir -p "$HOME/.config/mise"
    $DRY_RUN_CMD ln -sfn "$repo/home/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
    $DRY_RUN_CMD ${pkgs.mise}/bin/mise dot apply --yes || true
  '';

  home.activation.miseInstall = lib.hm.dag.entryAfter [ "miseDotfiles" ] ''
    $DRY_RUN_CMD ${pkgs.mise}/bin/mise install --yes || true
  '';

  # ---------------------------------------------------------------------
  # External git-based configs (nvim / tpm) — kept as git clones rather than
  # translated into programs.neovim / programs.tmux so you can iterate on
  # them outside Nix.
  # ---------------------------------------------------------------------
  home.activation.cloneNvim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.config/nvim" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/NaruseNia/nvim.git "$HOME/.config/nvim"
    fi
  '';

  home.activation.cloneTpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
  '';
}
