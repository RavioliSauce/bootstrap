#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '==> %s\n' "$*"
}

error() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--help [topic]]

Bootstrap a Debian/Ubuntu-style desktop environment and apply dotfiles.

Options:
  -h, --help         Show this help and exit.
  --help fstab       Show how to recreate the external-drive mounts.

Before running:
  export GITHUB_USERNAME=your-github-username

What this script does:
  - Installs apt packages for git, shell tools, bspwm, rofi, sxhkd, dunst,
    polybar, picom, Alacritty, Thunar, Xorg, GVFS, PipeWire audio, Bluetooth,
    and build tools.
  - Installs GitHub CLI from the official apt repository if gh is missing.
  - Installs uv, then uv tools: tldr and ruff.
  - Runs chezmoi init --apply "$GITHUB_USERNAME" to apply dotfiles.
  - Installs Tailscale, nvm LTS Node.js, and @openai/codex via npm.
  - Downloads the desktop background to ~/Pictures/picture.jpg.
  - Installs JetBrainsMono Nerd Font into ~/.local/share/fonts.
  - Enables and starts the bluetooth systemd service.

Manual steps after it finishes:
  gh auth login
  codex login --device-auth
  sudo tailscale up

Notes:
  - This script uses sudo for apt, systemd, and repository setup.
  - It downloads and executes upstream installer scripts for uv, chezmoi,
    Tailscale, and nvm.
  - Deno installation is currently disabled in the script.
  - External-drive fstab mounts are not configured automatically. Run
    ./bootstrap.sh --help fstab for the current manual setup.
EOF
}

fstab_help() {
  cat <<'EOF'
Usage: ./bootstrap.sh --help fstab

Current external-drive mount setup:

  UUID=7e2ad205-d071-42a0-ba93-5d3c0fef354f /mnt/BigBoy ext4 defaults,nofail 0 2
  UUID=f05a401e-a996-4758-84b8-e6883ee292bc /mnt/LittleGuy ext4 defaults,nofail 0 2

What the fields mean:
  - UUID=... identifies the filesystem, which is more stable than /dev/sdX.
  - /mnt/BigBoy and /mnt/LittleGuy are the mount points.
  - ext4 is the filesystem type.
  - defaults,nofail uses normal mount options and allows boot to continue if
    the external drive is disconnected.
  - 0 disables dump.
  - 2 lets fsck check these filesystems after the root filesystem.

To recreate this on a fresh install:
  sudo mkdir -p /mnt/BigBoy /mnt/LittleGuy
  sudo cp /etc/fstab /etc/fstab.backup
  sudoedit /etc/fstab

Add these lines to /etc/fstab:
  UUID=7e2ad205-d071-42a0-ba93-5d3c0fef354f /mnt/BigBoy ext4 defaults,nofail 0 2
  UUID=f05a401e-a996-4758-84b8-e6883ee292bc /mnt/LittleGuy ext4 defaults,nofail 0 2

Then test before rebooting:
  sudo mount -a
  findmnt --target /mnt/BigBoy
  findmnt --target /mnt/LittleGuy

Useful verification commands:
  blkid
  lsblk -f
  findmnt -rn -S UUID=7e2ad205-d071-42a0-ba93-5d3c0fef354f
  findmnt -rn -S UUID=f05a401e-a996-4758-84b8-e6883ee292bc

If the UUIDs differ on another machine or after reformatting, use the UUIDs
shown by blkid or lsblk -f instead of the ones above.
EOF
}

handle_args() {
  case "$#" in
    0)
      return 0
      ;;
    1)
      case "$1" in
        -h|--help)
          usage
          exit 0
          ;;
      esac
      ;;
    2)
      if [[ "$1" == "--help" && "$2" == "fstab" ]]; then
        fstab_help
        exit 0
      fi
      ;;
  esac

  usage >&2
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
  bluetooth
  rfkill
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
  # curl -fsSL https://deno.land/install.sh | sh
  nvm_installs
  npm_installs
}

run_cmds() {
  mkdir -p "$HOME/Pictures"
  background_image
  font_install

  # systemd
  sudo systemctl enable --now bluetooth
}

main() {

  handle_args "$@"

  check_environment GITHUB_USERNAME

  install_packages

  run_remote_scripts

  run_cmds

  log "Bootstrap complete, don't forget to do 'gh auth login', 'codex login --device-auth', and 'sudo tailscale up'"
}

main "$@"
