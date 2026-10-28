#!/bin/sh
# Bootstrap portable dotfiles and essential CLI utilities (nvim, fzf, ripgrep).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/harveyr/dotfiles-public/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/harveyr/dotfiles-public/main/install.sh | sh -s -- --no-bins

set -eu

REPO_RAW="https://raw.githubusercontent.com/harveyr/dotfiles-public/main"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
INSTALL_BINS=1

for arg in "$@"; do
  case "$arg" in
    --no-bins) INSTALL_BINS=0 ;;
  esac
done
if [ "${SKIP_BINS:-0}" = "1" ]; then
  INSTALL_BINS=0
fi

export PATH="$LOCAL_BIN:$PATH"

log() {
  printf '[dotfiles] %s\n' "$*"
}

warn() {
  printf '[dotfiles] warning: %s\n' "$*" >&2
}

fetch() {
  url="$1"
  dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    warn "neither curl nor wget found; cannot download $url"
    return 1
  fi
}

# Parse `nvim --version` into "major minor" (e.g. "0 11" or "0 12")
get_nvim_version() {
  if ! command -v nvim >/dev/null 2>&1; then
    return 1
  fi
  ver=$(nvim --version 2>/dev/null | head -n 1 | sed -n 's/.*v\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
  if [ -z "$ver" ]; then
    return 1
  fi
  printf '%s' "$ver"
}

nvim_is_at_least_011() {
  ver=$(get_nvim_version) || return 1
  major=$(printf '%s' "$ver" | awk '{print $1}')
  minor=$(printf '%s' "$ver" | awk '{print $2}')
  if [ "$major" -gt 0 ] || { [ "$major" -eq 0 ] && [ "$minor" -ge 11 ]; }; then
    return 0
  fi
  return 1
}

# ----------------------------------------------------------------------------
# Best-effort utility installation (nvim, fzf, ripgrep)
# ----------------------------------------------------------------------------
run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n "$@"
  else
    return 1
  fi
}

try_pkg_install() {
  pkg="$1"
  if command -v apk >/dev/null 2>&1; then
    run_privileged apk add --no-cache "$pkg" >/dev/null 2>&1
  elif command -v apt-get >/dev/null 2>&1; then
    run_privileged env DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 || return 1
    run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null 2>&1
  elif command -v dnf >/dev/null 2>&1; then
    run_privileged dnf install -y -q "$pkg" >/dev/null 2>&1
  elif command -v brew >/dev/null 2>&1; then
    brew install -q "$pkg" >/dev/null 2>&1
  else
    return 1
  fi
}

install_nvim_tarball() {
  os=$(uname -s)
  arch=$(uname -m)

  case "${os}:${arch}" in
    Linux:x86_64)
      asset="nvim-linux-x86_64"
      ;;
    Linux:aarch64 | Linux:arm64)
      asset="nvim-linux-arm64"
      ;;
    Darwin:arm64)
      asset="nvim-macos-arm64"
      ;;
    Darwin:x86_64)
      asset="nvim-macos-x86_64"
      ;;
    *)
      warn "unsupported platform for prebuilt Neovim tarball (${os}/${arch})"
      return 1
      ;;
  esac

  url="https://github.com/neovim/neovim/releases/latest/download/${asset}.tar.gz"
  tmpdir=$(mktemp -d)
  if fetch "$url" "$tmpdir/nvim.tar.gz" && tar -xzf "$tmpdir/nvim.tar.gz" -C "$tmpdir"; then
    install_dir="$HOME/.local/$asset"
    rm -rf "$install_dir"
    mkdir -p "$HOME/.local" "$LOCAL_BIN"
    mv "$tmpdir/$asset" "$install_dir"
    ln -sf "$install_dir/bin/nvim" "$LOCAL_BIN/nvim"
    rm -rf "$tmpdir"
    if "$LOCAL_BIN/nvim" --version >/dev/null 2>&1; then
      return 0
    fi
    rm -f "$LOCAL_BIN/nvim"
  fi
  rm -rf "$tmpdir"
  return 1
}

install_fzf_fallback() {
  if ! command -v git >/dev/null 2>&1; then
    warn "git not found; skipping fzf fallback install"
    return 1
  fi
  fzf_dir="$HOME/.fzf"
  if [ ! -d "$fzf_dir" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir" >/dev/null 2>&1 || return 1
  fi
  "$fzf_dir/install" --bin >/dev/null 2>&1 || return 1
  mkdir -p "$LOCAL_BIN"
  ln -sf "$fzf_dir/bin/fzf" "$LOCAL_BIN/fzf"
}

install_rg_fallback() {
  os=$(uname -s)
  arch=$(uname -m)
  rg_ver="14.1.1"

  case "${os}:${arch}" in
    Linux:x86_64)
      target_triple="x86_64-unknown-linux-musl"
      ;;
    Linux:aarch64 | Linux:arm64)
      target_triple="aarch64-unknown-linux-gnu"
      ;;
    Darwin:arm64)
      target_triple="aarch64-apple-darwin"
      ;;
    Darwin:x86_64)
      target_triple="x86_64-apple-darwin"
      ;;
    *)
      warn "unsupported platform for ripgrep static binary (${os}/${arch})"
      return 1
      ;;
  esac

  archive="ripgrep-${rg_ver}-${target_triple}.tar.gz"
  url="https://github.com/BurntSushi/ripgrep/releases/download/${rg_ver}/${archive}"
  tmpdir=$(mktemp -d)
  if fetch "$url" "$tmpdir/$archive" && tar -xzf "$tmpdir/$archive" -C "$tmpdir"; then
    mkdir -p "$LOCAL_BIN"
    cp "$tmpdir/ripgrep-${rg_ver}-${target_triple}/rg" "$LOCAL_BIN/rg"
    chmod +x "$LOCAL_BIN/rg"
    rm -rf "$tmpdir"
    return 0
  fi
  rm -rf "$tmpdir"
  return 1
}

ensure_bins() {
  if ! nvim_is_at_least_011; then
    log "installing Neovim (>= 0.11)..."
    if install_nvim_tarball || try_pkg_install neovim; then
      log "Neovim installed ($(nvim --version 2>/dev/null | head -n 1))"
    else
      warn "could not install Neovim >= 0.11; continuing with existing setup"
    fi
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    log "installing fzf..."
    if try_pkg_install fzf || install_fzf_fallback; then
      log "fzf installed"
    else
      warn "could not install fzf; continuing without it"
    fi
  fi

  if ! command -v rg >/dev/null 2>&1; then
    log "installing ripgrep..."
    if try_pkg_install ripgrep || install_rg_fallback; then
      log "ripgrep installed"
    else
      warn "could not install ripgrep; continuing without it"
    fi
  fi
}

# ----------------------------------------------------------------------------
# Place Neovim configuration (runs after Neovim binary is present)
# ----------------------------------------------------------------------------
detect_nvim_dir() {
  if [ -n "${NVIM_PROFILE:-}" ]; then
    if [ "$NVIM_PROFILE" = "0.11" ]; then
      printf 'nvim0.11'
    else
      printf 'nvim'
    fi
    return
  fi

  if ver=$(get_nvim_version); then
    major=$(printf '%s' "$ver" | awk '{print $1}')
    minor=$(printf '%s' "$ver" | awk '{print $2}')
    if [ "$major" -eq 0 ] && [ "$minor" -le 11 ]; then
      printf 'nvim0.11'
      return
    fi
  fi

  printf 'nvim'
}

install_nvim_config() {
  nvim_dir="$CONFIG_HOME/nvim"
  target="$nvim_dir/init.lua"
  profile=$(detect_nvim_dir)

  mkdir -p "$nvim_dir"
  if [ -f "$target" ]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$backup"
    log "backed up existing init.lua to $backup"
  fi

  log "installing Neovim config ($profile/init.lua) -> $target"
  fetch "$REPO_RAW/$profile/init.lua" "$target"
}

prewarm_nvim() {
  if command -v nvim >/dev/null 2>&1; then
    log "syncing Neovim plugins headlessly..."
    nvim --headless +qall >/dev/null 2>&1 || warn "headless plugin sync exited non-zero"
  fi
}

if [ "$INSTALL_BINS" -eq 1 ]; then
  ensure_bins
fi
install_nvim_config
prewarm_nvim
log "done"
