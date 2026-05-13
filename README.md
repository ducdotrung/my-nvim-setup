# dotfiles

Personal dotfiles for WSL2 Ubuntu + Neovim + tmux + zsh (Powerlevel10k).

## Setup on new machine

```bash
git clone https://github.com/ducdotrung/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

## Structure

| Path          | Description                       |
|---------------|-----------------------------------|
| `nvim/`       | Neovim config (lazy.nvim)         |
| `tmux/`       | tmux + tmux-resurrect/continuum   |
| `zsh/`        | Oh My Zsh + Powerlevel10k         |
| `wezterm/`    | WezTerm terminal (Windows)        |
