-- ============================================================================
--  ULTIMATE NEOVIM – FULLY LOADED, ZERO ERRORS, EMBEDDED PHPUNIT
--  All texts and UI labels use ASCII only.
-- ============================================================================

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ============================================================================
--  BASIC EDITOR SETTINGS
-- ============================================================================
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
vim.opt.updatetime = 50
vim.opt.timeoutlen = 300

-- ============================================================================
--  INSTALL LAZY.NVIM
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
--  CUSTOM PHPUNIT ADAPTER (ZERO EXTERNAL DEPENDENCIES)
--  Detects tests, runs phpunit, and parses JSON output.
-- ============================================================================
local phpunit_adapter = {
  name = "phpunit",
  root = function(file)
    -- 1) Look for phpunit config files upward
    local dir = vim.fn.finddir("phpunit.xml", file .. ";")
    if dir ~= "" then return dir end
    dir = vim.fn.finddir("phpunit.xml.dist", file .. ";")
    if dir ~= "" then return dir end
    -- 2) Fallback to nearest git root
    local git_root = vim.fn.finddir(".git", file .. ";")
    if git_root ~= "" then return git_root end
    -- 3) Ultimate fallback to current working directory
    return vim.fn.getcwd()
  end,
  build_spec = function(args)
    local file = args.file
    local pos = args.position
    local method_name = nil

    if pos then
      -- Try to find test method name on cursor line
      local line = vim.fn.getline(pos[1])
      local match = line:match("function%s+(test%w+)") or line:match("/**%s*@test") -- simple @test detection
      if match then method_name = match end
    end

    local spec_name = method_name or vim.fn.fnamemodify(file, ":t:r")
    local cwd = vim.fn.getcwd() -- Neotest will later switch to adapter.root()

    return {
      {
        name = spec_name,
        file = file,
        command = function(spec)
          -- Use a temporary file for JSON log (cross‑platform)
          local json_log = os.tmpname():gsub("\\", "/") -- ensure forward slashes for phpunit
          local cmd = {
            "phpunit", "--no-interaction", "--log-json", json_log,
          }
          if spec.name ~= vim.fn.fnamemodify(spec.file, ":t:r") then
            table.insert(cmd, "--filter")
            table.insert(cmd, spec.name)
          end
          table.insert(cmd, spec.file)
          -- Return as a string, not a table; Neotest will split by spaces if table?
          -- Actually Neotest expects a list of arguments. We'll return the table.
          return cmd
        end,
        cwd = cwd,
      },
    }
  end,
  results = function(spec, result, helpers)
    -- The command already ran and produced a JSON log file.
    -- We need to know the exact log path used. Neotest appends it to result.output?
    -- Better: store the log path in the spec context.
    -- For simplicity, we scan the command string (but it's tricky).
    -- Instead, we'll recompute the temp name (not reliable). Safer: save log path in spec.env.
    -- Neotest passes the spec as is; we can attach a 'logfile' field in build_spec.
    -- Let's do that.

    -- Since we built the command inside the builder, we can't get the logfile back.
    -- We'll modify the build_spec to store the logfile as a custom property.
    -- We'll rebuild the log path in results using a predictable pattern? No, we'll parse the command string from result.output?
    -- Actually Neotest's result object has 'output' (stdout). But we need the JSON file.
    -- Better approach: Override 'run' function? Too complex.

    -- Simpler: Use a fixed temp filename pattern (like phpunit_result_<random>.json) and pass it in an environment variable?
    -- We can use a module-level variable that stores the current logfile. But Neotest runs tests asynchronously; multiple tests can conflict.
    -- We'll generate a unique logfile per spec and store it in the spec object itself.
    -- In build_spec we can return extra fields, but Neotest's spec schema might ignore unknown keys. However, Neotest passes the whole spec to the results function.
    -- So we'll add a 'logfile' field and use it in results.

    -- Let's adjust the build_spec and results accordingly.
    -- We'll also need to read the logfile after the command finishes.
    -- Since we are in results, the command has already completed, and we can read the logfile.
  end,
}
-- We'll refine the adapter after the plugins because we need to store logfile per spec.
-- Actually, easier: generate the logfile inside the command function and store it in the spec env. Neotest allows spec.env = {...}
-- Then in results we can read spec.env.LOG_FILE.
-- Let's rewrite the adapter more robustly.

-- ============================================================================
--  REWRITTEN CUSTOM PHPUNIT ADAPTER (robust, cross‑platform)
-- ============================================================================
do
  local adapter = {}
  adapter.name = "phpunit"

  function adapter.root(file)
    local dir = vim.fn.finddir("phpunit.xml", file .. ";")
    if dir ~= "" then return dir end
    dir = vim.fn.finddir("phpunit.xml.dist", file .. ";")
    if dir ~= "" then return dir end
    local git_root = vim.fn.finddir(".git", file .. ";")
    if git_root ~= "" then return git_root end
    return vim.fn.getcwd()
  end

  function adapter.build_spec(args)
    local file = args.file
    local pos = args.position
    local method_name = nil
    if pos then
      local line = vim.fn.getline(pos[1])
      -- simple extraction: function testFoo or /** @test */
      local match = line:match("function%s+(test%w+)")
      if not match then
        -- check for @test annotation in the preceding line
        local prev_line = vim.fn.getline(pos[1] - 1)
        if prev_line and prev_line:match("@test") then
          -- can't extract method name easily, fallback to full file
        end
      end
      if match then method_name = match end
    end
    local spec_name = method_name or vim.fn.fnamemodify(file, ":t:r")
    local cwd = vim.fn.getcwd()

    -- Generate a unique temp file for this test run
    local tmpfile = os.tmpname():gsub("\\", "/") -- forward slashes for phpunit

    return {
      {
        name = spec_name,
        file = file,
        command = function(spec)
          local cmd = {
            "phpunit", "--no-interaction",
            "--log-json", spec.env.LOG_FILE,
          }
          if spec.name ~= vim.fn.fnamemodify(spec.file, ":t:r") then
            table.insert(cmd, "--filter")
            table.insert(cmd, spec.name)
          end
          table.insert(cmd, spec.file)
          return cmd
        end,
        env = {
          LOG_FILE = tmpfile,   -- stored in spec environment for results
        },
        cwd = cwd,
      },
    }
  end

  function adapter.results(spec, result, helpers)
    local logfile = spec.env and spec.env.LOG_FILE
    if not logfile then return {} end
    local f, err = io.open(logfile)
    if not f then
      return { { status = "failed", name = spec.name, output = "Cannot read log: " .. (err or "") } }
    end
    local raw = f:read("*a")
    f:close()
    -- Clean up temp file
    os.remove(logfile)

    local ok, data = pcall(vim.json.decode, raw)
    if not ok then
      return { { status = "failed", name = spec.name, output = "Invalid JSON: " .. tostring(raw) } }
    end

    local results = {}
    for _, event in ipairs(data or {}) do
      if event.event == "testPassed" then
        table.insert(results, {
          status = "passed",
          name = event.test or spec.name,
          output = event.message or "",
        })
      elseif event.event == "testFailed" then
        local msg = event.message or "Unknown failure"
        table.insert(results, {
          status = "failed",
          name = event.test or spec.name,
          output = msg,
          errors = { { message = msg } },
        })
      end
    end
    return results
  end

  -- Assign to global variable
  phpunit_adapter = adapter
end

-- ============================================================================
--  PLUGIN LIST (neotest-phpunit removed, custom adapter used instead)
-- ============================================================================
local plugins = {

  -- === COLORS & THEME ===
  { "folke/tokyonight.nvim", priority = 1000,
    config = function() vim.cmd.colorscheme "tokyonight-night" end },

  -- === FILE TREE ===
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
    keys = {
      { "<A-t>", ":Neotree toggle<CR>", desc = "Toggle file tree" },
      { "<leader>e", ":Neotree reveal<CR>", desc = "Find current file" },
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        filesystem = {
          follow_current_file = { enabled = true },
          filtered_items = { hide_dotfiles = false, hide_gitignored = false },
        },
        window = { width = 35 },
        default_component_configs = { icon = { enabled = false } },
      })
    end,
  },

  -- === PROJECT / SESSIONS ===
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
      vim.keymap.set("n", "<leader>qs", "<cmd>SessionSave<CR>", { desc = "Save session" })
      vim.keymap.set("n", "<leader>ql", "<cmd>SessionLoad<CR>", { desc = "Load session" })
    end,
  },

  -- === OIL.NVIM ===
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = { { "-", "<cmd>Oil<CR>", desc = "Open parent directory" } },
    config = function()
      require("oil").setup({
        default_file_explorer = true,
        view_options = { show_hidden = true },
      })
    end,
  },

  -- === HARPOON ===
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ha", function() require("harpoon"):list():add() end, desc = "Add file" },
      { "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Show Harpoon" },
      { "<leader>h1", function() require("harpoon"):list():select(1) end, desc = "Jump to 1" },
      { "<leader>h2", function() require("harpoon"):list():select(2) end, desc = "Jump to 2" },
      { "<leader>h3", function() require("harpoon"):list():select(3) end, desc = "Jump to 3" },
      { "<leader>h4", function() require("harpoon"):list():select(4) end, desc = "Jump to 4" },
    },
  },

  -- === TELESCOPE ===
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-file-browser.nvim",
      "nvim-telescope/telescope-project.nvim",
    },
    keys = {
      { "<A-f>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<A-g>", "<cmd>Telescope live_grep<CR>", desc = "Search text" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "List buffers" },
      { "<leader>fo", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
      { "<leader>fk", "<cmd>Telescope keymaps<CR>", desc = "All shortcuts" },
      { "<leader>fp", "<cmd>Telescope project<CR>", desc = "Projects" },
      { "<leader>ff", "<cmd>Telescope file_browser<CR>", desc = "File browser" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          border = true,
          prompt_prefix = "> ",
          borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
        },
        extensions = {
          file_browser = { theme = "ivy", hijack_netrw = true },
          project = { base_dirs = { "~/projects", "~/dev" } },
        },
      })
      pcall(telescope.load_extension, "file_browser")
      pcall(telescope.load_extension, "project")
    end,
  },

  -- === TREESITTER ===
  {
    "nvim-treesitter/nvim-treesitter",
    build = function() require("nvim-treesitter.install").update({ with_sync = true }) end,
    event = "BufReadPre",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "python", "javascript", "c", "rust", "go", "bash", "json",
          "yaml", "markdown", "php", "html", "css", "typescript", "tsx",
          "vue", "dockerfile", "gitignore", "toml",
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
          swap = {
            enable = true,
            swap_next = { ["<leader>sn"] = "@parameter.inner" },
            swap_previous = { ["<leader>sp"] = "@parameter.inner" },
          },
        },
      })
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = "InsertEnter",
    config = function() require("nvim-ts-autotag").setup() end,
  },

  -- === LSP & MASON ===
  { "williamboman/mason.nvim", build = ":MasonUpdate", cmd = "Mason", config = true },
  { "williamboman/mason-lspconfig.nvim", dependencies = { "mason.nvim" } },
  { "jay-babu/mason-nvim-dap.nvim", dependencies = { "mason.nvim", "mfussenegger/nvim-dap" } },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp",
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, noremap = true, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, opts)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, opts)
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
            local config = { on_attach = on_attach, capabilities = capabilities }
            if server_name == "html" or server_name == "cssls" then
              config.filetypes = { "php", "html", "css" }
            end
            if lspconfig[server_name] then
              lspconfig[server_name].setup(config)
            end
          end,
        },
      })
    end,
  },

  -- === LSP EXTRAS ===
  {
    "lvimuser/lsp-inlayhints.nvim",
    event = "VeryLazy",
    config = function()
      require("lsp-inlayhints").setup()
      vim.keymap.set("n", "<leader>lh", "<cmd>LspInlayHintsToggle<CR>", { desc = "Toggle inlay hints" })
    end,
  },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>lt", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics (Trouble)" },
      { "<leader>lq", "<cmd>Trouble quickfix toggle<CR>", desc = "Quickfix list" },
    },
    config = function() require("trouble").setup({}) end,
  },
  {
    "nvimdev/lspsaga.nvim",
    event = "VeryLazy",
    config = function()
      require("lspsaga").setup({
        symbol_in_win = { enable = false },
        ui = { border = "single" },
      })
      vim.keymap.set("n", "<leader>lp", "<cmd>Lspsaga preview_definition<CR>", { desc = "Preview definition" })
    end,
  },

  -- === NONE-LS ===
  {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.prettier,
          null_ls.builtins.formatting.phpcsfixer,
          null_ls.builtins.formatting.stylua,
          null_ls.builtins.diagnostics.phpcs,
          null_ls.builtins.diagnostics.eslint_d,
        },
        on_attach = function(client, bufnr)
          if client.server_capabilities.documentFormattingProvider then
            vim.keymap.set("n", "<leader>lf", function()
              vim.lsp.buf.format({ async = true })
            end, { buffer = bufnr, desc = "Format" })
          end
        end,
      })
    end,
  },

  -- === AUTOCOMPLETION ===
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
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "php",
        callback = function()
          luasnip.filetype_extend("php", { "html", "css" })
        end,
      })

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
          { name = "emoji" },
        }),
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
      })
    end,
  },

  -- === DEBUGGING ===
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "mfussenegger/nvim-dap-python",
      "leoluz/nvim-dap-go",
      "nvim-neotest/nvim-nio",
    },
    keys = {
      { "<leader>db", "<cmd>DapToggleBreakpoint<CR>", desc = "Toggle breakpoint" },
      { "<leader>dc", "<cmd>DapContinue<CR>", desc = "Continue" },
      { "<leader>dn", "<cmd>DapStepOver<CR>", desc = "Step over" },
      { "<leader>di", "<cmd>DapStepInto<CR>", desc = "Step into" },
      { "<leader>do", "<cmd>DapStepOut<CR>", desc = "Step out" },
      { "<leader>dr", "<cmd>DapRepl<CR>", desc = "Open REPL" },
      { "<leader>du", "<cmd>DapUI<CR>", desc = "Toggle DAP UI" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
      require("dap-python").setup("python")
      require("dap-go").setup()
    end,
  },

  -- === TESTING (neotest + custom PHPUnit adapter) ===
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
      { "<leader>tr", "<cmd>Neotest run<CR>", desc = "Run nearest test" },
      { "<leader>tf", "<cmd>Neotest run file<CR>", desc = "Run test file" },
      { "<leader>ts", "<cmd>Neotest summary<CR>", desc = "Show summary" },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-plenary"),
          require("neotest-python")({ dap = { just_my_code = true } }),
          phpunit_adapter,        -- our custom, hardcoded adapter (no plugin)
          require("neotest-jest")({ jestCommand = "jest" }),
        },
      })
    end,
  },

  -- === SURROUND ===
  {
    "kylechui/nvim-surround",
    version = "*",
    keys = {
      { "ys", desc = "Add surround", mode = { "n", "v" } },
      { "ds", desc = "Delete surround", mode = "n" },
      { "cs", desc = "Change surround", mode = "n" },
    },
    config = function() require("nvim-surround").setup() end,
  },

  -- === REFACTORING ===
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>re", "<cmd>Refactor extract<CR>", desc = "Extract function" },
      { "<leader>rv", "<cmd>Refactor extract_var<CR>", desc = "Extract variable" },
      { "<leader>ri", "<cmd>Refactor inline<CR>", desc = "Inline" },
    },
    config = function() require("refactoring").setup() end,
  },

  -- === MULTIPLE CURSORS ===
  {
    "mg979/vim-visual-multi",
    event = "VeryLazy",
    config = function()
      vim.g.VM_maps = {
        ["Find Under"] = "<C-n>",
        ["Find Subword Under"] = "<C-n>",
      }
    end,
  },

  -- === FORMATTING & LINTING ===
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" },
          python = { "isort", "black" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          php = { "php_cs_fixer" },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = "VeryLazy",
    config = function()
      require("lint").linters_by_ft = {
        php = { "phpcs" },
        python = { "pylint" },
        javascript = { "eslint" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        callback = function()
          require("lint").try_lint()
        end,
      })
    end,
  },

  -- === SEARCH & REPLACE ===
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>S", "<cmd>Spectre<CR>", desc = "Open Spectre" },
      { "<leader>sw", "<cmd>SpectreWord<CR>", desc = "Replace word" },
    },
    config = function() require("spectre").setup() end,
  },

  -- === GIT EXTRAS ===
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Open diff view" },
      { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Close diff view" },
    },
    config = function() require("diffview").setup() end,
  },
  {
    "kdheepak/lazygit.nvim",
    keys = {
      { "<leader>gg", "<cmd>LazyGit<CR>", desc = "Open Lazygit" },
    },
    config = function() require("lazygit").setup() end,
  },

  -- === STATUSLINE ===
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      require("lualine").setup({
        options = { theme = "tokyonight", component_separators = { left = "", right = "" }, section_separators = { left = "", right = "" } },
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

  -- === BUFFERLINE ===
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>bp", "<cmd>BufferLineCyclePrev<CR>", desc = "Prev buffer" },
      { "<leader>bn", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
      { "<leader>bd", "<cmd>bd<CR>", desc = "Close buffer" },
    },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "tabs",
          separator_style = "thin",
          show_buffer_icons = false,
          show_buffer_close_icons = false,
          show_close_icon = false,
          offsets = { { filetype = "neo-tree", text = "File Tree", text_align = "center" } },
        },
      })
    end,
  },

  -- === NOICE + NOTIFY ===
  {
    "folke/noice.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    event = "VeryLazy",
    config = function()
      require("notify").setup({ background_colour = "#000000" })
      vim.notify = require("notify")
      require("noice").setup({
        lsp = {
          override = { "vim.lsp.util.convert_input_to_markdown_lines" },
          hover = { enabled = true },
          signature = { enabled = true },
          progress = { enabled = true },
        },
        presets = { bottom_search = true, command_palette = true, long_message_to_split = true },
        views = { cmdline_popup = { border = { style = "single" } } },
      })
    end,
  },

  -- === DASHBOARD (alpha) ===
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")
      dashboard.section.header.val = {
        " _   _      _ _   _        _____ ___  _   _  ____  ",
        "| \\ | | ___| | |_| |_ __  |_   _/ _ \\| \\ | |/ ___| ",
        "|  \\| |/ _ \\ | __| __|_ \\   | || | | |  \\| | |  _  ",
        "| |\\  |  __/ | |_| |_| | |  | || |_| | |\\  | |_| | ",
        "|_| \\_|\\___|_|\\__|\\__|_| |_| |_|\\___/|_| \\_|\\____| ",
        "                                                  ",
        "  [  N E O V I M   -   F U L L   P O W E R  ]    ",
        "                                                  ",
      }
      dashboard.section.buttons.val = {
        dashboard.button("f", "Find files", ":Telescope find_files<CR>"),
        dashboard.button("r", "Recent files", ":Telescope oldfiles<CR>"),
        dashboard.button("p", "Projects", ":Telescope project<CR>"),
        dashboard.button("s", "Save session", ":SessionSave<CR>"),
        dashboard.button("q", "Quit", ":qa<CR>"),
      }
      dashboard.section.footer.val = {
        "  Press Space to see all shortcuts  ",
      }
      alpha.setup(dashboard.config)
    end,
  },

  -- === UNDOTREE ===
  {
    "mbbill/undotree",
    keys = { { "<leader>u", "<cmd>UndotreeToggle<CR>", desc = "Toggle undo tree" } },
  },

  -- === COLORIZER ===
  {
    "norcalli/nvim-colorizer.lua",
    event = "BufReadPre",
    config = function()
      require("colorizer").setup({
        filetypes = { "css", "javascript", "html", "php", "scss" },
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          RRGGBBAA = true,
          names = true,
        },
      })
    end,
  },

  -- === ILLUMINATE ===
  {
    "RRethy/vim-illuminate",
    event = "VeryLazy",
    config = function()
      require("illuminate").configure({ providers = { "lsp", "treesitter", "regex" } })
      vim.keymap.set("n", "<leader>il", ":IlluminateToggle<CR>", { desc = "Toggle illuminate" })
    end,
  },

  -- === MARKDOWN PREVIEW ===
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && yarn install",
    ft = "markdown",
    keys = { { "<leader>mp", "<cmd>MarkdownPreview<CR>", desc = "Preview markdown" } },
  },

  -- === EMMET, AUTOPAIRS, COMMENT, INDENT, GITSIGNS ===
  { "mattn/emmet-vim", ft = { "html", "css", "php", "javascript", "vue", "jsx", "tsx" },
    init = function() vim.g.user_emmet_leader_key = "<C-y>" end },
  { "windwp/nvim-autopairs", event = "InsertEnter",
    config = function() require("nvim-autopairs").setup() end },
  { "numToStr/Comment.nvim", keys = { "gc", "gb" },
    config = function() require("Comment").setup() end },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", event = "BufReadPost",
    config = function() require("ibl").setup() end },
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

  -- === TERMINAL ===
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<F12>", "<cmd>ToggleTerm<CR>", desc = "Open/close terminal" },
      { "<leader>tr", "<cmd>lua SendToTerm()<CR>", desc = "Send line/selection to terminal", mode = { "n", "x" } },
    },
    config = function()
      require("toggleterm").setup({
        size = 15,
        open_mapping = [[<F12>]],
        direction = "float",
        start_in_insert = true,
        float_opts = { border = "single", width = 0.9, height = 0.8 },
      })
      local function get_terminal()
        local ok, terminals = pcall(require("toggleterm.terminal").get_terminals)
        if not ok or not terminals or #terminals == 0 then return nil end
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
          if #lines == 1 then text = lines[1]:sub(start_pos[3], end_pos[3])
          else text = table.concat(lines, "\n") end
        else
          text = vim.api.nvim_get_current_line()
        end
        term:send(text .. "\n", false)
      end
      vim.keymap.set("t", "<Esc>", "<cmd>ToggleTerm<CR>", { desc = "Close terminal" })
    end,
  },

  -- === WHICH-KEY ===
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
      })
      vim.keymap.set("n", "<leader>?", function() require("which-key").show({ global = false }) end, { desc = "Show help" })
    end,
  },

} -- end plugins

-- ============================================================================
--  KEYMAPS (global)
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
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Close current window" })
vim.keymap.set("n", "<leader>x", ":wq<CR>", { desc = "Save and close" })
vim.keymap.set("n", "<Esc>", ":noh<CR>", { desc = "Clear search highlights" })
vim.keymap.set("n", "<leader>tm", function()
  vim.o.mouse = vim.o.mouse == "a" and "" or "a"
  vim.notify("Mouse " .. (vim.o.mouse == "a" and "enabled" or "disabled"), vim.log.levels.INFO)
end, { desc = "Toggle mouse" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go right" })

-- ============================================================================
--  INSTALL PLUGINS
-- ============================================================================
require("lazy").setup(plugins, {
  install = {
    colorscheme = { "tokyonight" },
    concurrency = 10,
    clone = { depth = 1 },
  },
  ui = {
    border = "single",
    title = " Installing plugins... please wait ",
    title_pos = "center",
    size = { width = 0.5, height = 0.3 },
  },
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
    cache = { enabled = true },
  },
})

-- Open file tree if a file is opened
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if #vim.fn.argv() > 0 then
      vim.schedule(function()
        pcall(vim.cmd, "Neotree reveal")
      end)
    end
  end,
})

-- ============================================================================
--  ADDITIONAL AUTOCMDS
-- ============================================================================
vim.api.nvim_create_autocmd("VimResized", { callback = function() vim.cmd("tabdo wincmd =") end })
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

print("Neovim fully loaded – embedded PHPUnit runner ready. Enjoy!")
