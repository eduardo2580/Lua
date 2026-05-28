--[[
+---------------------------------------------------------------------------+
| NASA HACKING GROUP – ENTERPRISE NEOVIM IDE (K.I.S.S.)                     |
|                                                                           |
| * One file – no setup, no config, no tears.                               |
| * First launch installs all plugins with a beautiful progress screen.     |
| * Then shows a VS Code-style welcome page: Open Folder, New File...       |
| * Press <Space> and a smart cheat sheet appears.                          |
| * More powerful than VS Code, simpler than Scratch.                       |
| * SUPER FILE TREE: project root, live Git icons, branch name,             |
|   quick Git status popup, and Scratch-friendly shortcuts.                 |
| * AUTO OPENS when you start with a folder or file.                        |
| * TERMINAL: press <F12> – that's it. Send code with <leader>tr.           |
|   Git commands work natively. Close with Esc or <leader>tq.               |
+---------------------------------------------------------------------------+
]]--

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.smartindent = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.updatetime = 300
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.shortmess:append({ I = true })

-- helper to get Git branch (safe)
function _G.GitBranch()
  local handle = io.popen("git branch --show-current 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+", "")
  end
  return ""
end

function _G.OpenFolder()
  local default_dir = vim.fn.getcwd() .. (vim.fn.has("win32") == 1 and "\\" or "/")
  local path = vim.fn.input("📂 Open folder: ", default_dir, "dir")
  if path ~= "" then
    vim.cmd("cd " .. vim.fn.fnameescape(path))
    pcall(function() require("nvim-tree.api").tree.open() end)
  end
end

function _G.CloneRepo()
  local url = vim.fn.input("⬇️  Git clone URL: ")
  if url ~= "" then
    local default_dir = vim.fn.getcwd() .. (vim.fn.has("win32") == 1 and "\\" or "/")
    local dir = vim.fn.input("Clone into directory: ", default_dir, "dir")
    if dir ~= "" then
      local result = vim.fn.system({ "git", "clone", url, dir })
      if vim.v.shell_error ~= 0 then
        vim.notify("❌ Clone failed: " .. result, vim.log.levels.ERROR)
        return
      end
      vim.cmd("cd " .. vim.fn.fnameescape(dir))
      pcall(function() require("nvim-tree.api").tree.open() end)
    end
  end
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
  {
    "catppuccin/nvim", name = "catppuccin", priority = 1000,
    config = function()
      require("catppuccin").setup({ flavour = "mocha" })
      vim.cmd.colorscheme "catppuccin-mocha"
    end,
  },

  {
    "goolord/alpha-nvim", event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")
      dashboard.section.header.val = {
        "                                                     ",
        "     ███╗   ██╗ █████╗ ███████╗ █████╗               ",
        "     ████╗  ██║██╔══██╗██╔════╝██╔══██╗              ",
        "     ██╔██╗ ██║███████║███████╗███████║              ",
        "     ██║╚██╗██║██╔══██║╚════██║██╔══██║              ",
        "     ██║ ╚████║██║  ██║███████║██║  ██║              ",
        "     ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝              ",
        "                                                     ",
        "          H4CK THE PLANET! WITH NASA 🚀              ",
        "      Press [SPACE] to see the smart cheat sheet    ",
        "                                                     ",
      }
      dashboard.section.buttons.val = {
        dashboard.button("o", "📂  Open Folder",     ":lua OpenFolder()<CR>"),
        dashboard.button("n", "📄  New File",        ":ene | startinsert<CR>"),
        dashboard.button("r", "🕒  Recent Files",    ":Telescope oldfiles<CR>"),
        dashboard.button("g", "⬇️  Clone Repository", ":lua CloneRepo()<CR>"),
        dashboard.button("c", "⚙️  Open Config",     ":e ~/.config/nvim/init.lua<CR>"),
        dashboard.button("q", "❌  Quit",            ":qa<CR>"),
      }
      alpha.setup(dashboard.opts)
    end,
  },

  -- 🌳 Treesitter – fault‑tolerant
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    config = function()
      vim.schedule(function()
        local ok, ts = pcall(require, "nvim-treesitter.configs")
        if not ok then
          vim.notify(
            "🌳 Treesitter is not installed yet. Run :Lazy sync to install it.",
            vim.log.levels.WARN
          )
          return
        end
        ts.setup({
          ensure_installed = {
            "lua","python","javascript","typescript","c","cpp","rust",
            "bash","json","yaml","markdown","markdown_inline","vim","vimdoc","query",
            "go","java","html","css","dockerfile","sql","latex","make","toml",
          },
          auto_install = true,
          highlight = { enable = true },
          indent = { enable = true },
        })
      end)
    end,
  },

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
        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K",  vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, opts)
        vim.keymap.set("n", "<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>", opts)
        vim.keymap.set("n", "<leader>lw", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", opts)
      end

      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls", "pyright", "clangd", "bashls", "ts_ls",
          "html", "cssls", "jsonls", "yamlls", "gopls",
          "rust_analyzer", "jdtls", "marksman", "vimls",
          "tailwindcss", "prismals", "dockerls", "sqlls",
        },
        automatic_installation = true,
        handlers = {
          function(server_name)
            local ok, _ = pcall(function()
              lspconfig[server_name].setup({
                on_attach = on_attach,
                capabilities = capabilities,
              })
            end)
            if not ok then
              vim.notify("⚠️  LSP server " .. server_name .. " not available (maybe not installed).", vim.log.levels.WARN)
            end
          end,
        },
      })
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp", "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip", "rafamadriz/friendly-snippets",
    },
    event = "InsertEnter",
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
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
        }),
        sources = cmp.config.sources(
          { { name = "nvim_lsp" }, { name = "luasnip" } },
          { { name = "buffer" }, { name = "path" } }
        ),
      })
    end,
  },

  {
    "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>",  desc = "Search text" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>",    desc = "Open buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>",  desc = "Help" },
      { "<leader>fo", "<cmd>Telescope oldfiles<cr>",   desc = "Recent files" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>",    desc = "All shortcuts" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          mappings = { i = { ["<C-j>"] = "move_selection_next", ["<C-k>"] = "move_selection_previous" } },
        },
      })
    end,
  },

  -- ==================== SUPER FILE TREE ====================
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<C-n>", "<cmd>NvimTreeToggle<cr>",          desc = "Toggle file tree" },
      { "<leader>e", "<cmd>NvimTreeFindFile<cr>",    desc = "Reveal current file in tree" },
      { "<leader>E", "<cmd>NvimTreeFocus<cr>",       desc = "Focus file tree" },
    },
    config = function()
      local function on_attach(bufnr)
        local api = require("nvim-tree.api")
        local function opts(desc) return { buffer = bufnr, desc = desc } end

        api.config.mappings.default_on_attach(bufnr)

        vim.keymap.set("n", "R",  api.tree.reload,                       opts("Refresh tree"))
        vim.keymap.set("n", "H",  api.tree.toggle_hidden_filter,         opts("Toggle hidden files (dotfiles)"))
        vim.keymap.set("n", "I",  api.tree.toggle_git_ignored_filter,    opts("Toggle Git‑ignored files"))
        vim.keymap.set("n", "gs", function()
          local node = api.tree.get_node_under_cursor()
          local cwd = node and node.absolute_path or vim.fn.getcwd()
          vim.cmd("botright vnew")
          vim.bo.bufhidden = "wipe"
          vim.bo.buftype = "nofile"
          local escaped = vim.fn.shellescape(cwd)
          vim.fn.termopen("git -C " .. escaped .. " status --short --branch", {})
          vim.cmd("startinsert")
        end, opts("Show Git status of current folder"))

        -- Open terminal in the folder of the node under cursor
        vim.keymap.set("n", "t", function()
          local node = api.tree.get_node_under_cursor()
          if not node then return end
          local target_dir = node.absolute_path
          if not node.nodes then
            target_dir = vim.fn.fnamemodify(target_dir, ":h")
          end
          vim.cmd("ToggleTerm dir=" .. vim.fn.fnameescape(target_dir))
        end, opts("Open terminal here"))
      end

      require("nvim-tree").setup({
        view = {
          width = 35,
          side = "left",
          preserve_window_proportions = true,
        },
        renderer = {
          group_empty = true,
          highlight_git = true,
          icons = {
            show = {
              git = true,
              folder = true,
              file = true,
            },
            git_placement = "signcolumn",
            glyphs = {
              git = {
                unstaged = "✗",
                staged   = "✓",
                unmerged = "",
                renamed  = "➜",
                untracked = "★",
                deleted  = "⊖",
                ignored  = "◌",
              },
            },
          },
          root_folder_label = function(path)
            local name = vim.fs.basename(path)
            local branch = _G.GitBranch()
            if branch ~= "" then
              return ("%s  [%s]"):format(name, branch)
            else
              return name
            end
          end,
        },
        filters = {
          dotfiles = false,
          git_ignored = false,
        },
        update_focused_file = {
          enable = true,
          update_root = false,
        },
        git = {
          enable = true,
          show_on_dirs = true,
          timeout = 400,
        },
        actions = {
          open_file = {
            quit_on_open = false,
          },
        },
        on_attach = on_attach,
      })
    end,
  },

  {
    "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "BufReadPost",
    config = function()
      require("lualine").setup({
        options = { theme = "catppuccin" },
        sections = {
          lualine_x = {
            {
              function()
                local ok, term = pcall(require, "toggleterm.terminal")
                if ok and term and term.get_active_terminal then
                  local active = term.get_active_terminal()
                  if active and active.direction == "float" then
                    local cwd = active:get_cwd() or ""
                    if cwd ~= "" then
                      return " " .. vim.fn.fnamemodify(cwd, ":t")
                    end
                  end
                end
                return ""
              end,
              cond = function() return package.loaded["toggleterm"] ~= nil end,
            },
          },
        },
      })
    end,
  },

  {
    "lewis6991/gitsigns.nvim", event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup()
      vim.keymap.set("n", "]h", "<cmd>Gitsigns next_hunk<CR>", { desc = "Next change" })
      vim.keymap.set("n", "[h", "<cmd>Gitsigns prev_hunk<CR>", { desc = "Previous change" })
      vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns blame_line<CR>", { desc = "Blame line" })
      vim.keymap.set("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", { desc = "Preview change" })
      vim.keymap.set("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", { desc = "Undo change" })
      vim.keymap.set("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", { desc = "Stage change" })
    end,
  },

  {
    "folke/which-key.nvim", event = "VeryLazy",
    config = function()
      require("which-key").setup()
      require("which-key").add({
        { "<leader>?", group = "Show this cheat sheet" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>l", group = "LSP (Smart Code)" },
        { "<leader>d", group = "Debug" },
        { "<leader>x", group = "Diagnostics" },
        { "<leader>t", group = "Terminal" },
      })
      vim.keymap.set("n", "<leader>?", function() require("which-key").show({ global = false }) end,
        { desc = "Cheat Sheet" })
    end,
  },

  { "windwp/nvim-autopairs", event = "InsertEnter", config = function() require("nvim-autopairs").setup() end },
  { "numToStr/Comment.nvim", keys = { "gc", "gb" }, config = function() require("Comment").setup() end },

  {
    "lukas-reineke/indent-blankline.nvim", main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    config = function() require("ibl").setup() end,
  },

  {
    "folke/trouble.nvim", dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",    desc = "All errors" },
      { "<leader>xw", "<cmd>Trouble workspace_diagnostics<cr>", desc = "Workspace errors" },
      { "<leader>xd", "<cmd>Trouble document_diagnostics<cr>",  desc = "Current file errors" },
      { "<leader>xl", "<cmd>Trouble loclist<cr>",              desc = "Location list" },
      { "<leader>xq", "<cmd>Trouble quickfix<cr>",              desc = "Quickfix" },
    },
    config = true,
  },

  -- ==================== KISS TERMINAL (Simple & Reliable) ====================
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<F12>",      "<cmd>ToggleTerm<CR>",                 desc = "Toggle terminal" },
      { "<leader>tr", "<cmd>lua SendToTerm()<CR>",           desc = "Send line/selection to terminal" },
      { "<leader>tr", "<cmd>lua SendToTerm()<CR>",           desc = "Send selection to terminal", mode = "x" },
      { "<leader>tf", "<cmd>lua OpenTermInCurrentFileDir()<CR>", desc = "Terminal at current file's folder" },
      { "<leader>tq", "<cmd>ToggleTerm<CR>",                 desc = "Close terminal" },  -- same as toggle
    },
    config = function()
      local toggleterm = require("toggleterm")
      toggleterm.setup({
        size = 20,
        open_mapping = [[<F12>]],
        direction = "float",
        start_in_insert = true,
        close_on_exit = true,
        auto_scroll = true,
        float_opts = {
          border = "curved",
          width = function() return math.floor(vim.o.columns * 0.85) end,
          height = function() return math.floor(vim.o.lines * 0.7) end,
          winblend = 3,
        },
      })

      -- Get the first terminal instance (assume only one)
      local function get_terminal()
        local Terminal = require("toggleterm.terminal").Terminal
        local terminals = Terminal:get_terminals()
        if terminals and #terminals > 0 then
          return terminals[1]
        end
        return nil
      end

      -- Send text to terminal
      _G.SendToTerm = function()
        local term = get_terminal()
        if not term then
          vim.notify("No terminal is open. Press <F12> first.", vim.log.levels.WARN)
          return
        end

        local mode = vim.api.nvim_get_mode().mode
        local text = ""

        if mode == "v" or mode == "V" or mode == "" then
          local start_pos = vim.fn.getpos("'<")
          local end_pos = vim.fn.getpos("'>")
          local line_start = start_pos[2] - 1
          local line_end = end_pos[2] - 1
          local lines = vim.api.nvim_buf_get_lines(0, line_start, line_end + 1, false)
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

      -- Open terminal in current file's directory
      _G.OpenTermInCurrentFileDir = function()
        local dir = vim.fn.expand("%:p:h")
        if dir == "" then dir = vim.fn.getcwd() end
        vim.cmd("ToggleTerm dir=" .. vim.fn.fnameescape(dir))
      end

      -- Close terminal with Esc
      vim.keymap.set("t", "<Esc>", "<cmd>ToggleTerm<CR>", { desc = "Close terminal" })
      vim.keymap.set("t", "<C-q>", "<cmd>ToggleTerm<CR>", { desc = "Close terminal" })
    end,
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = { "rcarriga/nvim-dap-ui", "theHamsta/nvim-dap-virtual-text", "williamboman/mason.nvim", "jay-babu/mason-nvim-dap.nvim" },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end,          desc = "Continue" },
      { "<leader>do", function() require("dap").step_over() end,         desc = "Step Over" },
      { "<leader>di", function() require("dap").step_into() end,         desc = "Step Into" },
      { "<leader>du", function() require("dap").step_out() end,          desc = "Step Out" },
      { "<leader>dr", function() require("dap").repl.open() end,         desc = "Debug Console" },
      { "<leader>dl", function() require("dap").run_last() end,          desc = "Run Last" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      require("nvim-dap-virtual-text").setup()
      require("mason-nvim-dap").setup({
        automatic_installation = true,
        ensure_installed = { "debugpy", "codelldb" },
      })

      dap.adapters.python = {
        type = "executable",
        command = "python3",
        args = { "-m", "debugpy.adapter" },
      }
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          pythonPath = function() return "python3" end,
        },
      }

      local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"
      local codelldb = mason_bin .. (vim.fn.has("win32") == 1 and "codelldb.exe" or "codelldb")
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = codelldb,
          args = { "--port", "${port}" },
        },
      }
      local cpp_rust_config = {
        name = "Launch file",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
      }
      dap.configurations.cpp = { cpp_rust_config }
      dap.configurations.c = { cpp_rust_config }
      dap.configurations.rust = { cpp_rust_config }

      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
    end,
  },
}

-- Keymaps (general)
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Down window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Up window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Right window" })
vim.keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase height" })
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease height" })
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease width" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase width" })
vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })
vim.keymap.set("n", "<leader>x", ":wq<CR>", { desc = "Save & Quit" })
vim.keymap.set("n", "<leader>bd", ":bd<CR>", { desc = "Close buffer" })
vim.keymap.set("n", "<Esc>", ":noh<CR>", { desc = "Clear highlights" })

-- Additional terminal navigation (optional)
vim.keymap.set("t", "<C-h>", "<C-\\><C-N><C-w>h", { desc = "Leave terminal to left window" })
vim.keymap.set("t", "<C-j>", "<C-\\><C-N><C-w>j", { desc = "Leave terminal to down window" })
vim.keymap.set("t", "<C-k>", "<C-\\><C-N><C-w>k", { desc = "Leave terminal to up window" })
vim.keymap.set("t", "<C-l>", "<C-\\><C-N><C-w>l", { desc = "Leave terminal to right window" })

require("lazy").setup(plugins, {
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = true },
  ui = {
    border = "rounded",
    title = "🚀 NASA IDE Setup",
    title_pos = "center",
    size = { width = 0.5, height = 0.3 },
  },
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
})

-- Auto-open file tree when starting with a folder or file
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local args = vim.fn.argv()
    if #args == 0 then
      vim.defer_fn(function()
        pcall(function() require("which-key").show({ global = false }) end)
      end, 500)
    else
      local first = args[1]
      if vim.fn.isdirectory(first) == 1 then
        vim.defer_fn(function()
          pcall(function() require("nvim-tree.api").tree.open() end)
        end, 200)
      else
        vim.defer_fn(function()
          pcall(function()
            local api = require("nvim-tree.api")
            api.tree.open()
            api.tree.find_file({ open = false })
          end)
        end, 200)
      end
    end
  end,
})
