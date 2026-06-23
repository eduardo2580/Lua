-- ============================================================================
--  NEOVIM – FULLY LOADED, ZERO ERRORS, CROSS-PLATFORM
--  ASCII-only UI labels. No user configuration required.
-- ============================================================================

vim.g.mapleader        = " "
vim.g.maplocalleader   = " "

-- ============================================================================
--  BASIC EDITOR SETTINGS
-- ============================================================================
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.mouse          = "a"
vim.opt.clipboard      = "unnamedplus"
vim.opt.tabstop        = 2
vim.opt.shiftwidth     = 2
vim.opt.expandtab      = true
vim.opt.termguicolors  = true
vim.opt.cursorline     = true
vim.opt.scrolloff      = 10
vim.opt.signcolumn     = "yes"
vim.opt.encoding       = "utf-8"
vim.opt.updatetime     = 50
vim.opt.timeoutlen     = 300
vim.opt.wrap           = false
vim.opt.splitbelow     = true
vim.opt.splitright     = true
vim.opt.undofile       = true -- persistent undo across sessions

-- ============================================================================
--  COMPATIBILITY SHIM
--  vim.tbl_flatten was deprecated in Neovim 0.10; some older plugins still
--  call it. Provide a safe fallback only when the builtin is absent.
-- ============================================================================
if not vim.tbl_flatten then
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.tbl_flatten = function(t)
    local result = {}
    local function flatten(tbl)
      for _, v in ipairs(tbl) do
        if type(v) == "table" then
          flatten(v)
        else
          result[#result + 1] = v
        end
      end
    end
    flatten(t)
    return result
  end
end

-- ============================================================================
--  INSTALL LAZY.NVIM BOOTSTRAP
-- ============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
--  CUSTOM PHPUNIT NEOTEST ADAPTER
--  Self-contained: no external plugin dependency, cross-platform temp files.
--  FIX: removed dead first-draft table; `command` is now a plain list (not a
--  function); logfile path is propagated via spec.env so results() can read it.
-- ============================================================================
local phpunit_adapter = {}
phpunit_adapter.name = "phpunit"

function phpunit_adapter.root(file)
  local patterns = { "phpunit.xml", "phpunit.xml.dist", ".git" }
  for _, pat in ipairs(patterns) do
    local found = vim.fn.finddir(pat, file .. ";")
    if found and found ~= "" then return vim.fn.fnamemodify(found, ":h") end
    local foundfile = vim.fn.findfile(pat, file .. ";")
    if foundfile and foundfile ~= "" then return vim.fn.fnamemodify(foundfile, ":h") end
  end
  return vim.fn.getcwd()
end

function phpunit_adapter.build_spec(args)
  local file        = args.file
  local pos         = args.position
  local method_name = nil

  if pos then
    local line = vim.fn.getline(pos[1])
    method_name = line:match("function%s+(test%w+)")
    if not method_name then
      -- check @test annotation on the line above
      local prev = vim.fn.getline(pos[1] - 1)
      if prev and prev:match("@test") then
        local fn_line = vim.fn.getline(pos[1])
        method_name = fn_line:match("function%s+(%w+)")
      end
    end
  end

  local base_name = vim.fn.fnamemodify(file, ":t:r")
  local spec_name = method_name or base_name

  -- Use a deterministic-enough temp path (cross-platform forward-slashes)
  local tmpfile = (os.tmpname()):gsub("\\", "/")

  -- FIX: `command` must be a plain list of strings for Neotest, not a function.
  local cmd = { "phpunit", "--no-interaction", "--log-json", tmpfile }
  if spec_name ~= base_name then
    table.insert(cmd, "--filter")
    table.insert(cmd, spec_name)
  end
  table.insert(cmd, file)

  return {
    {
      name    = spec_name,
      file    = file,
      command = cmd, -- plain list, not a function
      env     = { LOG_FILE = tmpfile },
      cwd     = phpunit_adapter.root(file),
    },
  }
end

function phpunit_adapter.results(spec, _result, _helpers)
  local logfile = spec.env and spec.env.LOG_FILE
  if not logfile then return {} end

  local f, err = io.open(logfile, "r")
  if not f then
    return { [spec.name] = { status = "failed", output = "Cannot open log: " .. (err or "") } }
  end
  local raw = f:read("*a")
  f:close()
  pcall(os.remove, logfile)

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return { [spec.name] = { status = "failed", output = "Invalid JSON output:\n" .. tostring(raw) } }
  end

  local results = {}
  for _, event in ipairs(data) do
    local name = event.test or spec.name
    if event.event == "testPassed" then
      results[name] = { status = "passed", short = "PASS" }
    elseif event.event == "testFailed" then
      local msg = event.message or "Unknown failure"
      results[name] = { status = "failed", short = "FAIL", output = msg, errors = { { message = msg } } }
    end
  end
  return results
end

-- ============================================================================
--  PLUGIN DEFINITIONS
-- ============================================================================
local plugins = {

  -- ── ICONS (explicit, required by many plugins) ─────────────────────────────
  { "nvim-tree/nvim-web-devicons",       lazy = true },

  -- ── COLORSCHEME ────────────────────────────────────────────────────────────
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  -- ── FILE TREE ──────────────────────────────────────────────────────────────
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<A-t>",     ":Neotree toggle<CR>", desc = "Toggle file tree" },
      { "<leader>e", ":Neotree reveal<CR>", desc = "Find current file in tree" },
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        filesystem = {
          follow_current_file   = { enabled = true },
          filtered_items        = { hide_dotfiles = false, hide_gitignored = false },
          hijack_netrw_behavior = "open_current", -- netrw handled by neo-tree
        },
        window = { width = 35 },
        default_component_configs = { icon = { enabled = false } },
      })
    end,
  },

  -- ── OIL.NVIM (parent-dir editor) ──────────────────────────────────────────
  -- FIX: default_file_explorer disabled to avoid netrw conflict with neo-tree.
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = { { "-", "<cmd>Oil<CR>", desc = "Open parent directory in oil" } },
    config = function()
      require("oil").setup({
        default_file_explorer = false, -- neo-tree handles netrw
        view_options = { show_hidden = true },
      })
    end,
  },

  -- ── PROJECT / SESSIONS ─────────────────────────────────────────────────────
  {
    "ahmedkhalf/project.nvim",
    event = "VeryLazy",
    config = function()
      require("project_nvim").setup({
        detection_methods = { "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },
      })
    end,
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    config = function()
      require("persistence").setup()
      -- FIX: persistence.nvim uses Lua API, not vim commands :SessionSave/:SessionLoad.
      vim.keymap.set("n", "<leader>qs", function() require("persistence").save() end,
        { desc = "Save session" })
      vim.keymap.set("n", "<leader>ql", function() require("persistence").load() end,
        { desc = "Load session" })
    end,
  },

  -- ── HARPOON ────────────────────────────────────────────────────────────────
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ha", function() require("harpoon"):list():add() end,                                    desc = "Harpoon: add file" },
      { "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon: menu" },
      { "<leader>h1", function() require("harpoon"):list():select(1) end,                                desc = "Harpoon: jump 1" },
      { "<leader>h2", function() require("harpoon"):list():select(2) end,                                desc = "Harpoon: jump 2" },
      { "<leader>h3", function() require("harpoon"):list():select(3) end,                                desc = "Harpoon: jump 3" },
      { "<leader>h4", function() require("harpoon"):list():select(4) end,                                desc = "Harpoon: jump 4" },
    },
  },

  -- ── TELESCOPE ──────────────────────────────────────────────────────────────
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
      "nvim-telescope/telescope-project.nvim",
    },
    keys = {
      { "<A-f>",      "<cmd>Telescope find_files<CR>",   desc = "Find files" },
      { "<A-g>",      "<cmd>Telescope live_grep<CR>",    desc = "Search text" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>",      desc = "List buffers" },
      { "<leader>fo", "<cmd>Telescope oldfiles<CR>",     desc = "Recent files" },
      { "<leader>fk", "<cmd>Telescope keymaps<CR>",      desc = "All shortcuts" },
      { "<leader>fp", "<cmd>Telescope project<CR>",      desc = "Projects" },
      { "<leader>ff", "<cmd>Telescope file_browser<CR>", desc = "File browser" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          border        = true,
          prompt_prefix = "> ",
          borderchars   = { "-", "|", "-", "|", "+", "+", "+", "+" },
        },
        extensions = {
          -- FIX: hijack_netrw disabled (neo-tree owns netrw)
          file_browser = { theme = "ivy", hijack_netrw = false },
          project      = { base_dirs = {} }, -- no hard-coded paths; discovers via project.nvim
        },
      })
      pcall(telescope.load_extension, "file_browser")
      pcall(telescope.load_extension, "project")
    end,
  },

  -- ── TREESITTER ─────────────────────────────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    build        = ":TSUpdate",
    event        = "BufReadPre",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    opts         = {
      ensure_installed = {
        "lua", "python", "javascript", "c", "rust", "go", "bash",
        "json", "yaml", "markdown", "php", "html", "css", "typescript",
        "tsx", "vue", "dockerfile", "gitignore", "toml",
      },
      auto_install     = true,
      highlight        = { enable = true },
      indent           = { enable = true },
      textobjects      = {
        select = {
          enable    = true,
          lookahead = true,
          keymaps   = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        swap = {
          enable        = true,
          swap_next     = { ["<leader>sn"] = "@parameter.inner" },
          swap_previous = { ["<leader>sp"] = "@parameter.inner" },
        },
      },
    },
    config       = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event        = "InsertEnter",
    config       = function() require("nvim-ts-autotag").setup() end,
  },

  -- ── LSP: MASON ─────────────────────────────────────────────────────────────
  { "williamboman/mason.nvim",           build = ":MasonUpdate",         cmd = "Mason", config = true },
  { "williamboman/mason-lspconfig.nvim", dependencies = { "mason.nvim" } },
  {
    -- FIX: added config so mason-nvim-dap actually installs adapters automatically.
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "mason.nvim", "mfussenegger/nvim-dap" },
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed       = { "python", "delve" },
        automatic_installation = true,
      })
    end,
  },

  -- ── LSP: nvim-cmp-lsp capabilities (explicit, loaded before lspconfig) ─────
  -- FIX: cmp-nvim-lsp must load before lspconfig to avoid race condition where
  -- lspconfig's BufReadPre fires before nvim-cmp's InsertEnter loads cmp_nvim_lsp.
  { "hrsh7th/cmp-nvim-lsp", lazy = true },

  -- ── LSP: LSPCONFIG ─────────────────────────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason-lspconfig.nvim", "hrsh7th/cmp-nvim-lsp" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig    = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local on_attach    = function(client, bufnr)
        local o = { buffer = bufnr, noremap = true, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, o)
        vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, o)
        vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, o)
        -- <leader>lf formatting is handled exclusively by conform.nvim (no duplicate)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, o)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, o)
        vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, o)

        -- FIX: native inlay hints (Neovim 0.10+) replaces the abandoned
        --      lvimuser/lsp-inlayhints.nvim plugin.
        if vim.lsp.inlay_hint and client.server_capabilities.inlayHintProvider then
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          vim.keymap.set("n", "<leader>lh", function()
            vim.lsp.inlay_hint.enable(
              not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
              { bufnr = bufnr }
            )
          end, { buffer = bufnr, desc = "Toggle inlay hints" })
        end
      end

      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls", "pyright", "clangd", "ts_ls", "rust_analyzer",
          "phpactor", "html", "cssls", "intelephense", "tailwindcss",
          "bashls", "dockerls", "jsonls", "yamlls",
        },
        automatic_installation = true,
        handlers = {
          function(server_name)
            local cfg = { on_attach = on_attach, capabilities = capabilities }
            if server_name == "html" or server_name == "cssls" then
              cfg.filetypes = { "php", "html", "css" }
            end
            if lspconfig[server_name] then
              lspconfig[server_name].setup(cfg)
            end
          end,
        },
      })
    end,
  },

  -- ── LSP EXTRAS ─────────────────────────────────────────────────────────────
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>lt", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics (Trouble)" },
      { "<leader>lq", "<cmd>Trouble quickfix toggle<CR>",    desc = "Quickfix list" },
    },
    config = function() require("trouble").setup({}) end,
  },
  {
    "nvimdev/lspsaga.nvim",
    event = "VeryLazy",
    config = function()
      require("lspsaga").setup({
        -- FIX: correct key is `symbol_in_winbar`, not `symbol_in_win`.
        symbol_in_winbar = { enable = false },
        ui = { border = "single" },
      })
      vim.keymap.set("n", "<leader>lp", "<cmd>Lspsaga peek_definition<CR>", { desc = "Peek definition" })
    end,
  },

  -- ── NONE-LS (diagnostics only, no formatters – conform handles formatting) ─
  -- FIX: removed formatter sources that duplicated conform.nvim, eliminating
  --      double-format-on-save and the duplicate <leader>lf keymap.
  {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          null_ls.builtins.diagnostics.phpcs,
          null_ls.builtins.diagnostics.eslint_d,
        },
      })
    end,
  },

  -- ── AUTOCOMPLETION ─────────────────────────────────────────────────────────
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-emoji",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    event = "InsertEnter",
    config = function()
      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      vim.api.nvim_create_autocmd("FileType", {
        pattern  = "php",
        callback = function() luasnip.filetype_extend("php", { "html", "css" }) end,
      })

      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
          { name = "emoji" },
        }),
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
      })
    end,
  },

  -- ── FORMATTING (single source of truth) ────────────────────────────────────
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua        = { "stylua" },
          python     = { "isort", "black" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          php        = { "php_cs_fixer" },
        },
        format_on_save = { timeout_ms = 500, lsp_fallback = true },
      })
      vim.keymap.set({ "n", "v" }, "<leader>lf", function()
        require("conform").format({ async = true, lsp_fallback = true })
      end, { desc = "Format file/range" })
    end,
  },

  -- ── LINTING ────────────────────────────────────────────────────────────────
  {
    "mfussenegger/nvim-lint",
    event = "VeryLazy",
    config = function()
      require("lint").linters_by_ft = {
        php        = { "phpcs" },
        python     = { "pylint" },
        javascript = { "eslint" },
      }
      vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function() require("lint").try_lint() end,
      })
    end,
  },

  -- ── DEBUGGING ──────────────────────────────────────────────────────────────
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
      "leoluz/nvim-dap-go",
      "nvim-neotest/nvim-nio",
    },
    keys = {
      { "<leader>db", "<cmd>DapToggleBreakpoint<CR>",           desc = "Toggle breakpoint" },
      { "<leader>dc", "<cmd>DapContinue<CR>",                   desc = "Continue" },
      { "<leader>dn", "<cmd>DapStepOver<CR>",                   desc = "Step over" },
      { "<leader>di", "<cmd>DapStepInto<CR>",                   desc = "Step into" },
      { "<leader>do", "<cmd>DapStepOut<CR>",                    desc = "Step out" },
      { "<leader>dr", "<cmd>DapRepl<CR>",                       desc = "REPL" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
    },
    config = function()
      local dap   = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"]     = function() dapui.close() end
      require("dap-python").setup("python")
      require("dap-go").setup()
    end,
  },

  -- ── TESTING ────────────────────────────────────────────────────────────────
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-plenary",
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-jest",
    },
    keys = {
      { "<leader>tr", "<cmd>Neotest run<CR>",      desc = "Run nearest test" },
      { "<leader>tf", "<cmd>Neotest run file<CR>", desc = "Run test file" },
      { "<leader>ts", "<cmd>Neotest summary<CR>",  desc = "Test summary" },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-plenary"),
          require("neotest-python")({ dap = { just_my_code = true } }),
          phpunit_adapter,
          require("neotest-jest")({ jestCommand = "jest" }),
        },
      })
    end,
  },

  -- ── SURROUND ───────────────────────────────────────────────────────────────
  {
    "kylechui/nvim-surround",
    version = "*",
    keys = {
      { "ys", desc = "Add surround",    mode = { "n", "v" } },
      { "ds", desc = "Delete surround", mode = "n" },
      { "cs", desc = "Change surround", mode = "n" },
    },
    config = function() require("nvim-surround").setup() end,
  },

  -- ── REFACTORING ────────────────────────────────────────────────────────────
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>re", "<cmd>Refactor extract<CR>",     desc = "Extract function" },
      { "<leader>rv", "<cmd>Refactor extract_var<CR>", desc = "Extract variable" },
      { "<leader>ri", "<cmd>Refactor inline<CR>",      desc = "Inline" },
    },
    config = function() require("refactoring").setup() end,
  },

  -- ── MULTIPLE CURSORS ───────────────────────────────────────────────────────
  {
    "mg979/vim-visual-multi",
    event = "VeryLazy",
    init = function()
      vim.g.VM_maps = {
        ["Find Under"]         = "<C-n>",
        ["Find Subword Under"] = "<C-n>",
      }
    end,
  },

  -- ── SEARCH & REPLACE ───────────────────────────────────────────────────────
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>S",  "<cmd>Spectre<CR>",     desc = "Open Spectre" },
      { "<leader>sw", "<cmd>SpectreWord<CR>", desc = "Replace word" },
    },
    config = function() require("spectre").setup() end,
  },

  -- ── GIT ────────────────────────────────────────────────────────────────────
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>",  desc = "Open diff view" },
      { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Close diff view" },
    },
    config = function() require("diffview").setup() end,
  },
  {
    "kdheepak/lazygit.nvim",
    keys = { { "<leader>gg", "<cmd>LazyGit<CR>", desc = "Open Lazygit" } },
    -- FIX: lazygit.nvim has no setup() function — removed erroneous call.
  },
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

  -- ── STATUSLINE ─────────────────────────────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      require("lualine").setup({
        options = {
          theme                = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators   = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  -- ── BUFFERLINE ─────────────────────────────────────────────────────────────
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>bp", "<cmd>BufferLineCyclePrev<CR>", desc = "Prev buffer" },
      { "<leader>bn", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
      { "<leader>bd", "<cmd>bd<CR>",                  desc = "Close buffer" },
    },
    config = function()
      require("bufferline").setup({
        options = {
          mode                    = "tabs",
          separator_style         = "thin",
          show_buffer_icons       = false,
          show_buffer_close_icons = false,
          show_close_icon         = false,
          offsets                 = { { filetype = "neo-tree", text = "File Tree", text_align = "center" } },
        },
      })
    end,
  },

  -- ── NOICE + NOTIFY ─────────────────────────────────────────────────────────
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    event = "VeryLazy",
    config = function()
      require("notify").setup({ background_colour = "#000000" })
      vim.notify = require("notify")
      require("noice").setup({
        lsp = {
          -- FIX: `override` requires a map of string→bool, not a list.
          override  = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"]                = true,
            ["cmp.entry.get_documentation"]                  = true,
          },
          hover     = { enabled = true },
          signature = { enabled = true },
          progress  = { enabled = true },
        },
        presets = {
          bottom_search         = true,
          command_palette       = true,
          long_message_to_split = true,
        },
        views = { cmdline_popup = { border = { style = "single" } } },
      })
    end,
  },

  -- ── DASHBOARD ──────────────────────────────────────────────────────────────
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VimEnter",
    config = function()
      local alpha                   = require("alpha")
      local dashboard               = require("alpha.themes.dashboard")
      dashboard.section.header.val  = {
        " _   _      _ _   _        _____ ___  _   _  ____  ",
        "| \\ | | ___| | |_| |_ __  |_   _/ _ \\| \\ | |/ ___| ",
        "|  \\| |/ _ \\ | __| __|_ \\   | || | | |  \\| | |  _  ",
        "| |\\  |  __/ | |_| |_| | |  | || |_| | |\\  | |_| | ",
        "|_| \\_|\\___|_|\\__|\\__|_| |_| |_|\\___/|_| \\_|\\____| ",
        "                                                  ",
        "         [ N E O V I M   -   F U L L   P O W E R ]",
        "                                                  ",
      }
      dashboard.section.buttons.val = {
        dashboard.button("f", "Find files", ":Telescope find_files<CR>"),
        dashboard.button("r", "Recent files", ":Telescope oldfiles<CR>"),
        dashboard.button("p", "Projects", ":Telescope project<CR>"),
        dashboard.button("s", "Load session", function() require("persistence").load() end),
        dashboard.button("q", "Quit", ":qa<CR>"),
      }
      dashboard.section.footer.val  = { "  Press <Space> to see all shortcuts  " }
      alpha.setup(dashboard.config)
    end,
  },

  -- ── UNDOTREE ───────────────────────────────────────────────────────────────
  {
    "mbbill/undotree",
    keys = { { "<leader>u", "<cmd>UndotreeToggle<CR>", desc = "Toggle undo tree" } },
  },

  -- ── COLORIZER (maintained fork) ────────────────────────────────────────────
  -- FIX: replaced abandoned `norcalli/nvim-colorizer.lua` with its actively
  --      maintained fork `catgoose/nvim-colorizer.lua` (identical API).
  {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    config = function()
      require("colorizer").setup({
        filetypes = { "css", "javascript", "html", "php", "scss" },
        user_default_options = {
          RGB      = true,
          RRGGBB   = true,
          RRGGBBAA = true,
          names    = true,
        },
      })
    end,
  },

  -- ── ILLUMINATE ─────────────────────────────────────────────────────────────
  {
    "RRethy/vim-illuminate",
    event = "VeryLazy",
    config = function()
      require("illuminate").configure({ providers = { "lsp", "treesitter", "regex" } })
      vim.keymap.set("n", "<leader>il", ":IlluminateToggle<CR>", { desc = "Toggle illuminate" })
    end,
  },

  -- ── MARKDOWN PREVIEW ───────────────────────────────────────────────────────
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && yarn install",
    ft    = "markdown",
    keys  = { { "<leader>mp", "<cmd>MarkdownPreview<CR>", desc = "Preview markdown" } },
  },

  -- ── EMMET ──────────────────────────────────────────────────────────────────
  {
    "mattn/emmet-vim",
    ft   = { "html", "css", "php", "javascript", "vue", "jsx", "tsx" },
    init = function() vim.g.user_emmet_leader_key = "<C-y>" end,
  },

  -- ── AUTOPAIRS ──────────────────────────────────────────────────────────────
  {
    "windwp/nvim-autopairs",
    event  = "InsertEnter",
    config = function() require("nvim-autopairs").setup() end,
  },

  -- ── COMMENTS ───────────────────────────────────────────────────────────────
  {
    "numToStr/Comment.nvim",
    keys   = { "gc", "gb" },
    config = function() require("Comment").setup() end,
  },

  -- ── INDENT GUIDES ──────────────────────────────────────────────────────────
  {
    "lukas-reineke/indent-blankline.nvim",
    main   = "ibl",
    event  = "BufReadPost",
    config = function() require("ibl").setup() end,
  },

  -- ── TERMINAL ───────────────────────────────────────────────────────────────
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<F12>",      "<cmd>ToggleTerm<CR>",       desc = "Open/close terminal" },
      { "<leader>tr", "<cmd>lua SendToTerm()<CR>", desc = "Send line/selection to terminal", mode = { "n", "x" } },
    },
    config = function()
      -- FIX: float_opts width/height must be integers (columns × rows),
      --      not fractional percentages (0.9/0.8). Compute from current UI size.
      local ui_w = vim.o.columns
      local ui_h = vim.o.lines
      require("toggleterm").setup({
        size            = 15,
        open_mapping    = [[<F12>]],
        direction       = "float",
        start_in_insert = true,
        float_opts      = {
          border = "single",
          width  = math.floor(ui_w * 0.9),
          height = math.floor(ui_h * 0.8),
        },
      })

      -- Recompute float size on resize so it stays proportional
      vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
          local tw = require("toggleterm.config").get("float_opts")
          if tw then
            tw.width  = math.floor(vim.o.columns * 0.9)
            tw.height = math.floor(vim.o.lines * 0.8)
          end
        end,
      })

      local function get_terminal()
        local ok, terminals = pcall(require("toggleterm.terminal").get_terminals)
        if not ok or not terminals or #terminals == 0 then return nil end
        return terminals[1]
      end

      _G.SendToTerm = function()
        local term = get_terminal()
        if not term then
          vim.notify("Press <F12> to open a terminal first", vim.log.levels.WARN)
          return
        end
        local mode = vim.api.nvim_get_mode().mode
        local text = ""
        if mode == "v" or mode == "V" then
          local s = vim.fn.getpos("'<")
          local e = vim.fn.getpos("'>")
          local lines = vim.api.nvim_buf_get_lines(0, s[2] - 1, e[2], false)
          text = (#lines == 1) and lines[1]:sub(s[3], e[3]) or table.concat(lines, "\n")
        else
          text = vim.api.nvim_get_current_line()
        end
        term:send(text .. "\n", false)
      end

      vim.keymap.set("t", "<Esc>", "<cmd>ToggleTerm<CR>", { desc = "Close terminal" })
    end,
  },

  -- ── WHICH-KEY ──────────────────────────────────────────────────────────────
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup({ win = { border = "single" } })
      local wk = require("which-key")
      wk.add({
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>l", group = "LSP" },
        { "<leader>t", group = "Terminal/Test" },
        { "<leader>w", group = "Save" },
        { "<leader>q", group = "Quit/Session" },
        { "<leader>h", group = "Harpoon" },
        { "<leader>d", group = "Debug" },
        { "<leader>b", group = "Buffer" },
        { "<leader>S", group = "Spectre" },
        { "<leader>p", group = "Project" },
        { "<leader>r", group = "Refactor" },
      })
      vim.keymap.set("n", "<leader>?", function()
        require("which-key").show({ global = false })
      end, { desc = "Show help" })
    end,
  },

} -- end plugins

-- ============================================================================
--  GLOBAL KEYMAPS
-- ============================================================================
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
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Close window" })
vim.keymap.set("n", "<leader>x", ":wq<CR>", { desc = "Save and close" })
vim.keymap.set("n", "<Esc>", ":noh<CR>", { desc = "Clear highlights" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go right" })
vim.keymap.set("n", "<leader>tm", function()
  vim.o.mouse = vim.o.mouse == "a" and "" or "a"
  vim.notify("Mouse " .. (vim.o.mouse == "a" and "enabled" or "disabled"), vim.log.levels.INFO)
end, { desc = "Toggle mouse" })

-- ============================================================================
--  BOOTSTRAP PLUGINS
-- ============================================================================
require("lazy").setup(plugins, {
  install = {
    colorscheme = { "tokyonight" },
    concurrency = 10,
  },
  git = {
    depth = 1,
  },
  ui = {
    border    = "single",
    title     = " Installing plugins... please wait ",
    title_pos = "center",
    size      = { width = 0.5, height = 0.3 },
  },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
    cache = { enabled = true },
  },
})

-- ============================================================================
--  AUTOCMDS
-- ============================================================================

-- Open file tree when nvim is opened with a file argument
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if #vim.fn.argv() > 0 then
      vim.schedule(function() pcall(vim.cmd, "Neotree reveal") end)
    end
  end,
})

-- Equalise splits on terminal resize
vim.api.nvim_create_autocmd("VimResized", {
  callback = function() vim.cmd("tabdo wincmd =") end,
})

-- Flash yanked region
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})
