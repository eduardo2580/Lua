# Neovim

A Neovim config for humans. Copy one file, restart, done.

---

## Installation

**Linux / Mac**
```bash
cp init.lua ~/.config/nvim/init.lua
```

**Windows**
```
%USERPROFILE%\AppData\Local\nvim\init.lua
```

Restart Neovim. Plugins install themselves — the installation window closes automatically when finished.

No extra steps.

---

## Shortcuts

All the essentials, no Vim muscle memory required.

| Key | Action |
|-----|--------|
| `Alt + t` | Open / close file tree |
| `Alt + f` | Find files |
| `Alt + g` | Search text inside files |
| `Alt + s` | Save file |
| `Alt + q` | Close window |
| `F12` | Open / close terminal |
| `Space` | Show all shortcuts |

You can also click around with your mouse.

---

## PHP / HTML / CSS Features (NEW)

Editing `.php` files now gives you full HTML and CSS support inside the same buffer:

- **HTML tag autocompletion** – type `<div` and press `Tab`
- **CSS property suggestions** – type `backg` → `background-color`
- **Emmet expansion** – press `<C-y>,` (Ctrl+y then comma) to expand abbreviations like `div>p*2`
- **Automatic closing of HTML tags** – type `</` and the matching tag appears
- **PHP LSP** – go to definition, hover info, rename, code actions

No extra configuration required – it just works.

---

## What's Included

| Feature | Plugin |
|---------|--------|
| Color theme | tokyonight-night |
| File tree | neo-tree |
| Fuzzy finder | Telescope |
| Syntax highlighting | Treesitter (PHP, HTML, CSS, etc.) |
| Language servers (LSP) | mason + nvim-lspconfig |
| PHP LSP | phpactor (pure PHP, no Node.js) |
| HTML / CSS LSP | html-lsp + cssls |
| Autocompletion | nvim-cmp + LuaSnip |
| Snippets | friendly-snippets (HTML/CSS in PHP too) |
| Emmet | emmet-vim |
| Auto-close HTML tags | nvim-ts-autotag |
| Git change indicators | gitsigns |
| Floating terminal | toggleterm |
| Shortcut help menu | which-key |
| Auto-close brackets | nvim-autopairs |
| Toggle comments | Comment.nvim |
| Indent guides | indent-blankline |

---

## Language Support

**Pre‑configured LSP and Treesitter:**

Lua · Python · JavaScript / TypeScript · C / C++ · Rust · Go · Bash · JSON · YAML · Markdown  
**PHP · HTML · CSS**  ← new

Additional languages can be added via `:Mason`.

---

## LSP Keymaps

These activate automatically when a language server attaches.

| Key | Action |
|-----|--------|
| `gd` | Go to definition (works for PHP classes/functions, HTML, CSS) |
| `K` | Hover documentation |
| `Space lr` | Rename symbol |
| `Space la` | Code actions |
| `Space lf` | Format file |

---

## Git Keymaps

| Key | Action |
|-----|--------|
| `]h` | Next change |
| `[h` | Previous change |
| `Space gb` | Blame current line |

---

## Terminal

Press `F12` to open a floating terminal. Press `F12` or `Esc` to close it.

To send the current line (or a visual selection) to the terminal:

```
Space + tr
```

---

## Other Useful Keymaps

| Key | Action |
|-----|--------|
| `Space w` | Save file |
| `Space q` | Close window |
| `Space x` | Save and close |
| `Space bd` | Close buffer |
| `Space tm` | Toggle mouse on/off |
| `Esc` | Clear search highlights |
| `Alt + Arrow` | Move between split windows |
| `Space fb` | List open buffers |
| `Space fo` | Recent files |
| `Space fk` | Browse all keymaps |

---

## Requirements

- Neovim 0.9 or later
- Git (for plugin installation)
- **For PHP LSP**: [PHP](https://windows.php.net/download) must be installed and in your PATH (only if you edit PHP files).  
  *If you prefer the Node.js‑based PHP LSP (`intelephense`), change `phpactor` to `intelephense` in `ensure_installed` and install Node.js.*
- A [Nerd Font](https://www.nerdfonts.com) is optional – the config works without one.

---

## Customization

Everything lives in a single file (`init.lua`). To change things:

- **Theme** – swap `tokyonight-night` for `tokyonight-moon`, `tokyonight-storm`, or `tokyonight-day`
- **Tab width** – change `tabstop` and `shiftwidth` (default: 2)
- **Languages** – add entries to `ensure_installed` in the Treesitter and `mason-lspconfig` blocks
- **PHP LSP** – replace `phpactor` with `intelephense` if you prefer (requires Node.js)
- **Plugins** – add any lazy.nvim‑compatible plugin to the `plugins` table
