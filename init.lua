--[[
  SUPER SIMPLE NEOVIM
  -------------------
  Just copy this file to:
    ~/.config/nvim/init.lua   (Linux/Mac)
    %USERPROFILE%\AppData\Local\nvim\init.lua   (Windows)

  Then restart Neovim. Everything installs itself.

  EASY SHORTCUTS (just hold Alt and press a letter):
    Alt+t   ->  open file tree
    Alt+f   ->  find files
    Alt+g   ->  search text
    Alt+s   ->  save file
    Alt+q   ->  close window
    F12     ->  open terminal
    Space   ->  show all shortcuts

  That's it. No config, no tears.
]]

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Basic settings (easy on the eyes)
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.signcolumn = "yes"
vim.opt.encoding = "utf-8"

-- Helper to open a folder
function _G.OpenFolder()
  local path = vim.fn.input("Folder path: ", vim.fn.getcwd(), "dir")
  if path ~= "" then
    vim.cmd("cd " .. vim.fn.fnameescape(path))
    vim.cmd("Neotree reveal")
  end
end

-- Install lazy.nvim (plugin manager)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- List of plugins (everything you need, nothing you don't)
local plugins = {
  -- Color theme (pretty)
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme "tokyonight-night"
    end,
  },

  -- File tree (press Alt+t) - without devicons to avoid Unicode
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<A-t>", ":Neotree toggle<CR>", desc = "Toggle file tree" },
      { "<leader>e", ":Neotree reveal<CR>", desc = "Find current file in tree" },
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        filesystem = {
          follow_current_file = { enabled = true },
          filtered_items = { hide_dotfiles = false, hide_gitignored = false },
        },
        window = { width = 35 },
        -- Disable icons (they are Unicode)
        default_component_configs = {
          icon = { enabled = false },
        },
      })
    end,
  },

  -- Fuzzy finder (press Alt+f to find files, Alt+g to grep)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<A-f>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<A-g>", "<cmd>Telescope live_grep<CR>",  desc = "Search text" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>",    desc = "List buffers" },
      { "<leader>fo", "<cmd>Telescope oldfiles<CR>",   desc = "Recent files" },
      { "<leader>fk", "<cmd>Telescope keymaps<CR>",    desc = "All shortcuts" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          border = true,
          prompt_prefix = "> ",
          -- Use ASCII borders
          borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
        },
      })
    end,
  },

  -- Syntax highlighting and code understanding (auto-installs)
  {
    "nvim-treesitter/nvim-treesitter",
    build = function() require("nvim-treesitter.install").update({ with_sync = true }) end,
    lazy = false,
    config = function()
      local function setup()
        local ok, ts = pcall(require, "nvim-treesitter.configs")
        if not ok then vim.defer_fn(setup, 100) return end
        ts.setup({
          ensure_installed = { "lua", "python", "javascript", "c", "rust", "go", "bash", "json", "yaml", "markdown" },
          auto_install = true,
          highlight = { enable = true },
          indent = { enable = true },
        })
      end
      setup()
    end,
  },

  -- LSP and autocompletion (smart code help)
  { "williamboman/mason.nvim", build = ":MasonUpdate", cmd = "Mason", config = true },
  { "williamboman/mason-lspconfig.nvim", dependencies = { "mason.nvim" } },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason-lspconfig.nvim", "nvim-cmp" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, noremap = true, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K",  vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, opts)
      end
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "clangd", "ts_ls", "rust_analyzer" },
        automatic_installation = true,
        handlers = { function(server_name) lspconfig[server_name].setup({ on_attach = on_attach, capabilities = capabilities }) end },
      })
    end,
  },

  -- Autocomplete popup
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp", "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    event = "InsertEnter",
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },

  -- Git signs (see changes in the sidebar)
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    config = function()
      require("gitsigns").setup()
      vim.keymap.set("n", "]h", "<cmd>Gitsigns next_hunk<CR>", { desc = "Next change" })
      vim.keymap.set("n", "[h", "<cmd>Gitsigns prev_hunk<CR>", { desc = "Previous change" })
      vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns blame_line<CR>", { desc = "Blame line" })
    end,
  },

  -- Floating terminal (press F12) – fixed API call
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<F12>", "<cmd>ToggleTerm<CR>", desc = "Open/close terminal" },
      { "<leader>tr", "<cmd>lua SendToTerm()<CR>", desc = "Send current line to terminal", mode = "n" },
      { "<leader>tr", "<cmd>lua SendToTerm()<CR>", desc = "Send selection to terminal", mode = "x" },
    },
    config = function()
      require("toggleterm").setup({
        size = 15,
        open_mapping = [[<F12>]],
        direction = "float",
        start_in_insert = true,
        float_opts = { border = "single", width = 0.9, height = 0.8 },  -- ASCII border
      })

      local function get_terminal()
        local ok, terminals = pcall(require("toggleterm.terminal").get_terminals)
        if not ok or not terminals or #terminals == 0 then
          return nil
        end
        return terminals[1]
      end

      _G.SendToTerm = function()
        local term = get_terminal()
        if not term then
          vim.notify("Press <F12> to open terminal first", vim.log.levels.WARN)
          return
        end
        local mode = vim.api.nvim_get_mode().mode
        local text = ""
        if mode == "v" or mode == "V" then
          local start_pos = vim.fn.getpos("'<")
          local end_pos = vim.fn.getpos("'>")
          local lines = vim.api.nvim_buf_get_lines(0, start_pos[2]-1, end_pos[2], false)
          if #lines == 1 then
            text = lines[1]:sub(start_pos[3], end_pos[3])
          else
            text = table.concat(lines, "\n")
          end
        else
          text = vim.api.nvim_get_current_line()
        end
        term:send(text .. "\n", false)
      end

      vim.keymap.set("t", "<Esc>", "<cmd>ToggleTerm<CR>", { desc = "Close terminal" })
    end,
  },

  -- Help menu (press Space)
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      -- Use ASCII border (single line box)
      require("which-key").setup({
        win = { border = "single" },
      })
      local wk = require("which-key")
      wk.add({
        { "<leader>?", group = "Help" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>l", group = "LSP" },
        { "<leader>t", group = "Terminal" },
        { "<leader>w", group = "Save" },
        { "<leader>q", group = "Quit" },
      })
      vim.keymap.set("n", "<leader>?", function() require("which-key").show({ global = false }) end, { desc = "Show help" })
    end,
  },

  -- Extra useful tools (autopairs, comments, indent lines)
  { "windwp/nvim-autopairs", event = "InsertEnter", config = function() require("nvim-autopairs").setup() end },
  { "numToStr/Comment.nvim", keys = { "gc", "gb" }, config = function() require("Comment").setup() end },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", event = "BufReadPost", config = function() require("ibl").setup() end },
}

-- ==================== EASY ALT KEYMAPS ====================
vim.keymap.set("n", "<A-t>", ":Neotree toggle<CR>", { desc = "File tree" })
vim.keymap.set("n", "<A-f>", ":Telescope find_files<CR>", { desc = "Find files" })
vim.keymap.set("n", "<A-g>", ":Telescope live_grep<CR>", { desc = "Search text" })
vim.keymap.set("n", "<A-s>", ":w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<A-q>", ":q<CR>", { desc = "Close window" })
vim.keymap.set("n", "<A-x>", ":wq<CR>", { desc = "Save and close" })

vim.keymap.set("n", "<A-Left>", "<C-w>h", { desc = "Left window" })
vim.keymap.set("n", "<A-Down>", "<C-w>j", { desc = "Down window" })
vim.keymap.set("n", "<A-Up>", "<C-w>k", { desc = "Up window" })
vim.keymap.set("n", "<A-Right>", "<C-w>l", { desc = "Right window" })

vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Close current window" })
vim.keymap.set("n", "<leader>x", ":wq<CR>", { desc = "Save and close" })
vim.keymap.set("n", "<leader>bd", ":bd<CR>", { desc = "Close buffer" })
vim.keymap.set("n", "<Esc>", ":noh<CR>", { desc = "Clear search highlights" })

vim.keymap.set("n", "<leader>tm", function()
  vim.o.mouse = vim.o.mouse == "a" and "" or "a"
  vim.notify("Mouse " .. (vim.o.mouse == "a" and "enabled" or "disabled"), vim.log.levels.INFO)
end, { desc = "Toggle mouse" })

-- Install all plugins (ASCII border)
require("lazy").setup(plugins, {
  install = { colorscheme = { "tokyonight" } },
  ui = {
    border = "single",   -- ASCII border
    title = "Installing plugins... please wait",
    title_pos = "center",
    size = { width = 0.5, height = 0.3 },
  },
  performance = { rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } } },
})

-- Welcome screen with pure ASCII
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local args = vim.fn.argv()
    if #args == 0 then
      vim.defer_fn(function()
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = 70,
          height = 18,
          row = (vim.o.lines - 18) / 2,
          col = (vim.o.columns - 70) / 2,
          style = "minimal",
          border = "single",   -- ASCII border
        })
        vim.api.nvim_win_set_option(win, "winblend", 10)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
          "",
          "  +------------------------------------------------------+",
          "  |          WELCOME TO SUPER SIMPLE NEOVIM             |",
          "  +------------------------------------------------------+",
          "",
          "  EASY SHORTCUTS (hold Alt and press a letter):",
          "     Alt + t   ->  open file tree",
          "     Alt + f   ->  find files",
          "     Alt + g   ->  search text inside files",
          "     Alt + s   ->  save current file",
          "     Alt + q   ->  close current window",
          "     F12       ->  open terminal",
          "     Space     ->  show all shortcuts",
          "",
          "  You can also click with your mouse.",
          "",
          "  Press any key to close this window and start coding.",
          "",
        })
        vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<cmd>q<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(buf, "n", "<Space>", "<cmd>q<CR>", { noremap = true, silent = true })
        for _, key in ipairs({ "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z" }) do
          vim.api.nvim_buf_set_keymap(buf, "n", key, "<cmd>q<CR>", { noremap = true, silent = true })
        end
      end, 200)
    else
      vim.defer_fn(function() pcall(vim.cmd, "Neotree reveal") end, 200)
    end
  end,
})
