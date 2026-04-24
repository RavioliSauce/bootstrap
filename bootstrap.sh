#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '==> %s\n' "$*"
}

error() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

APT_PACKAGES=(
  git
  curl
  jq
  unzip
  wget
  fontconfig
  tmux
  ripgrep
  fzf
  micro
  bat
  btop
  bspwm
  rofi
  sxhkd
  feh
  fonts-noto-color-emoji
  dunst
  polybar
  picom
  alacritty
  thunar
  build-essential
  xorg
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-utils
  gvfs
  gvfs-backends
  gvfs-fuse
  pipewire-audio
  alsa-utils
  rtkit
)

check_environment() {
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      error "$var environment variable is not set, you can set it like this: export $var=your-value"
    fi
  done
}

background_image() {
  wget --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36" -O "$HOME/Pictures/picture.jpg" "https://images.pexels.com/photos/36315456/pexels-photo-36315456.jpeg?w=1920&h=1280"
}

font_install() {
  mkdir -p ~/.local/share/fonts
  wget -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -o ~/.local/share/fonts/JetBrainsMono.zip -d ~/.local/share/fonts/
  fc-cache -fv
  rm -f ~/.local/share/fonts/JetBrainsMono.zip
}

github_install() {
  local out

  if command -v gh >/dev/null 2>&1; then
    log "gh already installed"
    return 0
  fi

  out="$(mktemp)"
  trap 'rm -f "${out:-}"' RETURN

  if ! command -v wget >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y wget
  fi

  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  sudo install -m 644 "$out" /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y gh
  rm -f "$out"
  trap - RETURN
}

uv_installs() {
  export PATH="$HOME/.local/bin:$PATH"
  uv tool install tldr
  uv tool install ruff
}

npm_installs() {
  export PATH="$HOME/.local/bin:$PATH"
  npm i -g @openai/codex
}

nvm_installs() {
  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"

  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    PROFILE=/dev/null NVM_DIR="$NVM_DIR" bash -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash'
  fi

  [ -s "$NVM_DIR/nvm.sh" ] || error "nvm install did not create $NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  command -v nvm >/dev/null 2>&1 || error "nvm failed to load"
  nvm install --lts
}

install_packages() {
  sudo apt-get update
  sudo apt-get install -y "${APT_PACKAGES[@]}"
  github_install
}

run_remote_scripts() {
  curl -LsSf https://astral.sh/uv/install.sh | sh
  uv_installs

  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply "$GITHUB_USERNAME"
  curl -fsSL https://tailscale.com/install.sh | sh
  curl -fsSL https://deno.land/install.sh | sh
  nvm_installs
  npm_installs
}

run_cmds() {
  mkdir -p "$HOME/Pictures"
  background_image
  font_install
}

main() {

  check_environment GITHUB_USERNAME

  install_packages

  run_remote_scripts

  run_cmds

  log "Bootstrap complete, don't forget to do 'gh auth login', 'codex login --device-auth', and 'sudo tailscale up'"
}

main "$@"
