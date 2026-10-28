# dotfiles-public

Public dotfiles repo. These will generally be simplified versions of my everyday dotfiles that I can hastily shim onto machines I don't own for short-term tasks.

## Installing

### Bootstrap (auto-detects Neovim version + installs `fzf` & `ripgrep`)

```sh
curl -fsSL https://raw.githubusercontent.com/harveyr/dotfiles-public/main/install.sh | sh
```

Config only (skip binary installation):

```sh
curl -fsSL https://raw.githubusercontent.com/harveyr/dotfiles-public/main/install.sh | sh -s -- --no-bins
```

### Direct file download (Neovim v0.12+)

```sh
curl -fsSL --create-dirs -o ~/.config/nvim/init.lua https://raw.githubusercontent.com/harveyr/dotfiles-public/main/nvim/init.lua
```

### Neovim v0.11-

```sh
curl -fsSL --create-dirs -o ~/.config/nvim/init.lua https://raw.githubusercontent.com/harveyr/dotfiles-public/refs/heads/main/nvim0.11/init.lua
```

