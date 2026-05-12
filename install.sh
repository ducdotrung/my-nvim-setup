#!/bin/bash
DOTFILES="$(cd "$(dirname "$0")" && pwd)"

echo "Linking dotfiles..."

# nvim
mkdir -p ~/.config/nvim
ln -sf "$DOTFILES/nvim" ~/.config/nvim

# tmux
ln -sf "$DOTFILES/tmux/.tmux.conf" ~/.tmux.conf

# zsh
ln -sf "$DOTFILES/zsh/.zshrc" ~/.zshrc
ln -sf "$DOTFILES/zsh/.p10k.zsh" ~/.p10k.zsh

echo "Done! Run 'source ~/.zshrc' to apply."
