# Neovim Python Setup

This configuration includes the Python workflow from the `python` branch of
the [Neovim Starter Kit](https://github.com/bcampolo/nvim-starter-kit): Pyright,
Treesitter, formatting, linting, debugging, and test integration.

## Prerequisites

- Neovim 0.9.1 or newer
- A true-color terminal and a Nerd Font
- Git and [ripgrep](https://github.com/BurntSushi/ripgrep)
- Node.js and npm
- Python 3.8 or newer
- Python provider: `python -m pip install pynvim`

On Linux, install `xclip` or `xsel` for system clipboard support. Windows and
macOS use their native clipboard integrations.

The first startup uses Mason to install the Python tools used by this config:
`black`, `debugpy`, `flake8`, `isort`, `mypy`, and `pylint`.

Run `:CheckPrerequisites` inside Neovim to check the external requirements.