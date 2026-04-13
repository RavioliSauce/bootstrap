#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '==> %s\n' "$*"
}

error() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

check_environment() {
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      error "$var environment variable is not set, you can set it like this: export $var=your-value"
    fi
  done
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
  sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null < "$out"
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y gh
  rm -f "$out"
  trap - RETURN
}

install_packages() {
  sudo apt-get update
  sudo apt-get install -y git curl jq unzip fontconfig tmux ripgrep fzf micro glow btop
  github_install
}

run_remote_scripts() {
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$GITHUB_USERNAME"
  curl -fsSL https://tailscale.com/install.sh | sh
  curl -LsSf https://astral.sh/uv/install.sh | sh
  curl -fsSL https://deno.land/install.sh | sh
}

run_cmds() {
  sudo tailscale up
  source "$HOME/.bashrc"
}


main() {

  check_environment GITHUB_USERNAME

  install_packages

  run_remote_scripts

  run_cmds

  log "Bootstrap complete"
}

main "$@"
