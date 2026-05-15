#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[info]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }
step()  { echo -e "\n${BLUE}==> $*${NC}"; }

has() { command -v "$1" &>/dev/null; }

# ── OS / distro detection ─────────────────────────────────────────────────────
OS="$(uname -s)"
PLATFORM=""
PKG_MANAGER=""

case "$OS" in
  Darwin)
    PLATFORM="macos"
    ;;
  Linux)
    PLATFORM="linux"
    # WSL: GUI apps (wezterm) run on Windows, not inside the distro
    grep -qi microsoft /proc/version 2>/dev/null && PLATFORM="wsl"
    if   has apt-get; then PKG_MANAGER="apt"
    elif has dnf;     then PKG_MANAGER="dnf"
    elif has pacman;  then PKG_MANAGER="pacman"
    else error "No supported package manager found (apt / dnf / pacman)"
    fi
    ;;
  *)
    error "Unsupported OS: $OS"
    ;;
esac

# ── Homebrew (macOS) ──────────────────────────────────────────────────────────
install_homebrew() {
  if has brew; then info "Homebrew already installed"; return; fi
  step "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if   [[ -f /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]];    then eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# ── git-delta for Linux (not in most default repos) ──────────────────────────
install_delta_linux() {
  if has delta; then info "git-delta already installed"; return; fi
  step "Installing git-delta"
  local version="0.17.0"
  local arch; arch="$(uname -m)"
  case "$arch" in
    x86_64)          arch_tag="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64)   arch_tag="aarch64-unknown-linux-gnu" ;;
    *) warn "Unknown arch $arch — skipping git-delta"; return ;;
  esac
  local tmpdir; tmpdir="$(mktemp -d)"
  curl -fsSL "https://github.com/dandavison/delta/releases/download/${version}/git-delta_${version}_${arch_tag}.tar.gz" \
    | tar -xz -C "$tmpdir"
  sudo mv "$(find "$tmpdir" -name delta -type f | head -1)" /usr/local/bin/delta
  rm -rf "$tmpdir"
  info "git-delta installed"
}

# ── Core packages ─────────────────────────────────────────────────────────────
install_packages() {
  step "Installing core packages ($PLATFORM)"
  case "$PLATFORM" in
    macos)
      install_homebrew
      brew install git zsh neovim tmux git-delta ripgrep fd fzf node
      brew install --cask wezterm
      # MesloLGS Nerd Font used by wezterm config
      brew install --cask font-meslo-lg-nerd-font 2>/dev/null || \
        warn "Could not install MesloLGS Nerd Font via brew cask — install manually if needed"
      ;;
    linux|wsl)
      case "$PKG_MANAGER" in
        apt)
          sudo apt-get update -q
          sudo apt-get install -y \
            git zsh neovim tmux ripgrep fd-find fzf curl \
            nodejs npm python3 python3-pip build-essential
          install_delta_linux
          ;;
        dnf)
          sudo dnf install -y \
            git zsh neovim tmux ripgrep fd-find fzf curl \
            nodejs npm python3 python3-pip
          install_delta_linux
          ;;
        pacman)
          sudo pacman -Sy --noconfirm \
            git zsh neovim tmux git-delta ripgrep fd fzf curl \
            nodejs npm python python-pip
          ;;
      esac
      if [[ "$PLATFORM" == "linux" ]]; then
        warn "Skipping wezterm — install from https://wezfurlong.org/wezterm/install/linux.html"
      fi
      ;;
  esac
}

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
install_omz() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then info "Oh My Zsh already installed"; return; fi
  step "Installing Oh My Zsh"
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

# ── Powerlevel10k + zsh plugins ───────────────────────────────────────────────
install_zsh_extras() {
  step "Installing Powerlevel10k and zsh plugins"
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [[ ! -d "$custom/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k"
    info "Powerlevel10k installed"
  else
    info "Powerlevel10k already installed"
  fi

  if [[ ! -d "$custom/plugins/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
    info "zsh-autosuggestions installed"
  else
    info "zsh-autosuggestions already installed"
  fi

  if [[ ! -d "$custom/plugins/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting"
    info "zsh-syntax-highlighting installed"
  else
    info "zsh-syntax-highlighting already installed"
  fi
}

# ── TPM (Tmux Plugin Manager) ─────────────────────────────────────────────────
install_tpm() {
  if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then info "TPM already installed"; return; fi
  step "Installing Tmux Plugin Manager (TPM)"
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
}

# ── Symlink dotfiles ──────────────────────────────────────────────────────────
link_dotfiles() {
  step "Linking dotfiles"
  mkdir -p ~/.config

  # nvim — symlink entire config dir
  ln -sfn "$DOTFILES/nvim" ~/.config/nvim
  info "~/.config/nvim -> $DOTFILES/nvim"

  # tmux
  ln -sf "$DOTFILES/tmux/.tmux.conf" ~/.tmux.conf
  info "~/.tmux.conf linked"

  # zsh
  ln -sf "$DOTFILES/zsh/.zshrc"    ~/.zshrc
  ln -sf "$DOTFILES/zsh/.p10k.zsh" ~/.p10k.zsh
  info "~/.zshrc and ~/.p10k.zsh linked"

  # git
  ln -sf "$DOTFILES/.gitconfig"          ~/.gitconfig
  ln -sf "$DOTFILES/.gitconfig-personal" ~/.gitconfig-personal
  ln -sf "$DOTFILES/.gitconfig-work"     ~/.gitconfig-work
  info "git configs linked"

  # wezterm — skip on WSL (runs on the Windows host)
  if [[ "$PLATFORM" != "wsl" ]]; then
    mkdir -p ~/.config/wezterm
    ln -sf "$DOTFILES/wezterm/.wezterm.lua" ~/.config/wezterm/wezterm.lua
    info "~/.config/wezterm/wezterm.lua linked"
  else
    info "WSL detected — skipping wezterm config symlink (manage from Windows side)"
  fi
}

# ── Default shell ─────────────────────────────────────────────────────────────
set_default_shell() {
  local zsh_path; zsh_path="$(which zsh 2>/dev/null)" || { warn "zsh not found, skipping shell change"; return; }
  if [[ "$SHELL" == "$zsh_path" ]]; then info "zsh is already the default shell"; return; fi
  step "Setting zsh as default shell"
  grep -qx "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
  chsh -s "$zsh_path"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  echo -e "${BLUE}"
  echo "  ┌─────────────────────────────────────────┐"
  printf "  │  dotfiles setup  %-22s│\n" "[$PLATFORM]"
  echo "  └─────────────────────────────────────────┘"
  echo -e "${NC}"

  install_packages
  install_omz
  install_zsh_extras
  install_tpm
  link_dotfiles
  set_default_shell

  echo ""
  echo -e "${GREEN}✓ Done!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Restart your terminal (or: exec zsh)"
  echo "  2. Open nvim — lazy.nvim will auto-install plugins on first launch"
  echo "  3. In tmux: prefix + I  to install plugins  (prefix = Ctrl+a)"
  [[ "$PLATFORM" == "macos" ]] && \
    echo "  4. Open WezTerm — MesloLGS Nerd Font should be installed via brew"
  echo ""
}

main "$@"
