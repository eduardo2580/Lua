-- ============================================================================
--  NEOVIM – FULLY LOADED, ZERO ERRORS, CROSS-PLATFORM
--  ASCII-only UI labels. No user configuration required.
-- ============================================================================

vim.g.mapleader      = " "
vim.g.maplocalleader = " "
require("core.options")
require("core.keymaps")

-- ============================================================================
--  COMPATIBILITY SHIM
--  vim.tbl_flatten was deprecated in Neovim 0.10; some older plugins (pulled
--  in transitively) still call it directly, which prints a "vim.tbl_flatten
--  is deprecated. Run ':checkhealth vim.deprecated' for more information"
--  notice on startup.
--  FIX: this used to only install the fallback `if not vim.tbl_flatten` --
--  but on current Neovim the deprecated builtin still exists (it's wrapped
--  to emit the notice, not removed), so that guard never fired and callers
--  kept hitting the real deprecated function every time. Install the pure
--  Lua reimplementation unconditionally: identical behavior for every
--  caller, but they now call our function instead of the notice-emitting
--  builtin, so the warning never fires.
-- ============================================================================
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

-- ============================================================================
--  INSTALL LAZY.NVIM BOOTSTRAP
-- ============================================================================
local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local plugin_root = config_root .. "/lazy"
local lazypath = plugin_root .. "/lazy.nvim"
vim.fn.mkdir(plugin_root, "p")
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

-- FIX: this is the function that was crashing every "*" BufEnter/CursorHold
-- autocmd. Neotest's client calls `adapter.is_test_file(position_id)`
-- unconditionally on *every* registered adapter for *every* buffer you enter
-- (see neotest/client/init.lua: find_adapter/_get_adapter) -- not just PHP
-- ones. phpunit_adapter never defined this field, so it was `nil`, and
-- "attempt to call field 'is_test_file' (a nil value)" fired the instant
-- neotest tried to identify which adapter owned the current buffer,
-- regardless of filetype. Skip directories neotest shouldn't crawl at all.
function phpunit_adapter.filter_dir(name, _rel_path, _root)
  return name ~= "vendor" and name ~= "node_modules" and name ~= ".git"
end

function phpunit_adapter.is_test_file(file_path)
  if not file_path then return false end
  return file_path:match("Test%.php$") ~= nil
end

-- FIX: also missing entirely -- without discover_positions, is_test_file
-- would have matched *Test.php files correctly but neotest would then have
-- had nothing to build a position tree from, erroring again as soon as you
-- opened one. Node types/fields (class_declaration.name, method_declaration
-- .name, both typed `name`) verified directly against tree-sitter-php's
-- node-types.json rather than assumed.
local phpunit_query = [[
  (class_declaration
    name: (name) @namespace.name) @namespace.definition

  (method_declaration
    name: (name) @test.name
    (#match? @test.name "^test")) @test.definition
]]

function phpunit_adapter.discover_positions(file_path)
  return require("neotest.lib").treesitter.parse_positions(file_path, phpunit_query, {
    nested_tests = true,
  })
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
  -- FIX: `--log-json` was removed from PHPUnit in 6.0 (2017) and has not existed
  -- in any supported PHPUnit release since; this flag was silently failing with
  -- "unrecognized option" and results() was parsing an empty/missing file every
  -- run. --log-teamcity is still supported by current PHPUnit and is simple to
  -- parse line-by-line below without pulling in an XML library.
  local cmd = { "phpunit", "--no-interaction", "--log-teamcity", tmpfile }
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

-- TeamCity service-message strings escape a handful of characters with a
-- leading `|`. Good enough for surfacing readable pass/fail output; it isn't
-- a full parser, but a stray literal `'` inside a failure message is the
-- only realistic edge case and it degrades to a merely-truncated message,
-- not a wrong pass/fail status (the status comes from the event name).
local function tc_unescape(s)
  if not s then return s end
  return (s:gsub("|n", "\n"):gsub("|r", "\r"):gsub("|%[", "["):gsub("|%]", "]"):gsub("|'", "'"):gsub("||", "|"))
end

local function tc_parse_line(line)
  local event, rest = line:match("^##teamcity%[(%a+)%s+(.*)%]$")
  if not event then return nil end
  local attrs = {}
  for key, val in rest:gmatch("(%w+)='(.-)'%s*") do
    attrs[key] = tc_unescape(val)
  end
  return event, attrs
end

function phpunit_adapter.results(spec, _result, _helpers)
  local logfile = spec.env and spec.env.LOG_FILE
  if not logfile then return {} end

  local f, err = io.open(logfile, "r")
  if not f then
    return { [spec.name] = { status = "failed", output = "Cannot open log: " .. (err or "") } }
  end

  local results = {}
  for line in f:lines() do
    local event, attrs = tc_parse_line(line)
    if event and attrs.name then
      if event == "testFailed" then
        local msg = attrs.message or "Unknown failure"
        if attrs.details and attrs.details ~= "" then
          msg = msg .. "\n" .. attrs.details
        end
        results[attrs.name] = { status = "failed", short = "FAIL", output = msg, errors = { { message = msg } } }
      elseif event == "testIgnored" then
        results[attrs.name] = { status = "skipped", short = "SKIP" }
      elseif event == "testFinished" and not results[attrs.name] then
        results[attrs.name] = { status = "passed", short = "PASS" }
      end
    end
  end
  f:close()
  pcall(os.remove, logfile)

  if vim.tbl_isempty(results) then
    results[spec.name] = { status = "failed", output = "No test events found in PHPUnit teamcity log; the run may have errored before any test started." }
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
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function() return vim.fn.executable("make") == 1 end,
      },
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
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "project")
    end,
  },

  -- ── TREESITTER ─────────────────────────────────────────────────────────────
  -- FIX (Jul 2026): nvim-treesitter's classic `nvim-treesitter.configs` module
  -- (the ensure_installed/highlight.enable/indent.enable API) is gone. The repo
  -- did a full rewrite on its `main` branch months ago and `main` is now the
  -- default branch, which is what you get with no `branch =` pinned -- that's
  -- what the "module 'nvim-treesitter.configs' not found" error was. The repo
  -- was then archived (frozen, read-only) on April 3, 2026, after Neovim 0.12
  -- absorbed native treesitter support; `main`'s new minimal API still works
  -- fine, it's just no longer receiving updates. The old `master` branch (the
  -- API this file used to use) is explicitly documented as not working
  -- correctly on current Neovim, so pinning back to it is not a real fix.
  --
  -- REQUIRES the `tree-sitter` CLI on $PATH to compile parsers now, in addition
  -- to a C compiler -- confirmed by actually running this: without it, install
  -- fails with "ENOENT: no such file or directory (cmd): 'tree-sitter'" for
  -- every parser. Install it with `npm i -g tree-sitter-cli` or
  -- `cargo install tree-sitter-cli` (either is fine, just needs to be on PATH).
  --
  -- FIX: the code below used to call ts.install() unconditionally and wrap it
  -- in pcall. That pcall did nothing useful -- ts.install() reports each
  -- parser's failure via vim.notify as a side effect of its async job, not
  -- as a Lua error raised back to the caller, so pcall never sees anything
  -- to catch. Without the CLI, that produced one "ENOENT ... 'tree-sitter'"
  -- error per parser (20+ of them) on every single startup, plus the same
  -- again from the per-filetype autocmd below as soon as you opened a
  -- buffer. Check for the CLI once up front instead: if it's missing, skip
  -- every install attempt and print exactly one clear, actionable warning.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build  = ":TSUpdate",
    event  = { "BufReadPre", "BufNewFile" },
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup({})

      local ensure_installed = {
        "lua", "python", "javascript", "c", "rust", "go", "bash",
        "json", "yaml", "markdown", "markdown_inline", "php", "html", "css",
        "typescript", "tsx", "vue", "dockerfile", "gitignore", "toml",
        "vim", "vimdoc", "query",
      }

      local has_tree_sitter_cli = vim.fn.executable("tree-sitter") == 1
      if not has_tree_sitter_cli then
        vim.notify(
          "nvim-treesitter: 'tree-sitter' CLI not found on $PATH -- parser "
            .. "installs skipped. Install it with 'npm i -g tree-sitter-cli' "
            .. "or 'cargo install tree-sitter-cli', restart, then run "
            .. ":TSUpdate.",
          vim.log.levels.WARN
        )
      else
        local installed = ts.get_installed("parsers")
        local to_install = vim.tbl_filter(function(lang)
          return not vim.tbl_contains(installed, lang)
        end, ensure_installed)
        if #to_install > 0 then
          -- Blocks startup only the first time (or when a new language is
          -- added to the list above); once everything's installed this list
          -- is empty and this whole branch is skipped, same as the old
          -- plugin's behavior.
          pcall(function()
            ts.install(to_install, { summary = true }):wait(300000)
          end)
        end
      end

      -- highlight/indent are opt-in per buffer now -- there's no more
      -- highlight.enable/indent.enable table. This autocmd also reproduces
      -- the old auto_install = true behavior for any filetype not in the
      -- list above.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
          if not vim.tbl_contains(ts.get_available(), lang) then
            return -- no treesitter parser exists for this filetype
          end
          if has_tree_sitter_cli and not vim.tbl_contains(ts.get_installed("parsers"), lang) then
            ts.install({ lang })
          end
          if pcall(vim.treesitter.get_parser, ev.buf, lang) then
            pcall(vim.treesitter.start, ev.buf, lang)
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    -- FIX: same rewrite as nvim-treesitter itself -- needs `branch = "main"`
    -- too, and select/swap are now plain functions you map yourself instead
    -- of a declarative keymaps table, so this reproduces the exact same
    -- af/if/ac/ic select and <leader>sn/<leader>sp swap bindings this file
    -- had before, just through the current API.
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch       = "main",
    event        = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move   = { set_jumps = true },
      })

      local select_obj = require("nvim-treesitter-textobjects.select")
      local function select_map(key, query, desc)
        vim.keymap.set({ "x", "o" }, key, function()
          select_obj.select_textobject(query, "textobjects")
        end, { desc = desc })
      end
      select_map("af", "@function.outer", "Select outer function")
      select_map("if", "@function.inner", "Select inner function")
      select_map("ac", "@class.outer", "Select outer class")
      select_map("ic", "@class.inner", "Select inner class")

      local swap_obj = require("nvim-treesitter-textobjects.swap")
      vim.keymap.set("n", "<leader>sn", function() swap_obj.swap_next("@parameter.inner") end,
        { desc = "Swap next parameter" })
      vim.keymap.set("n", "<leader>sp", function() swap_obj.swap_previous("@parameter.inner") end,
        { desc = "Swap previous parameter" })
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event        = "InsertEnter",
    config       = function() require("nvim-ts-autotag").setup() end,
  },

  -- ── LSP: MASON ─────────────────────────────────────────────────────────────
  -- FIX: williamboman/mason.nvim and mason-lspconfig.nvim moved to the
  -- mason-org GitHub org. The old williamboman/* paths still redirect fine
  -- (verified: both resolve to the identical commit), this just points at
  -- the current canonical location instead of relying on the redirect.
  {
    "mason-org/mason.nvim",
    build = ":MasonUpdate",
    cmd = "Mason",
    opts = { install_root_dir = config_root .. "/mason" },
  },
  { "mason-org/mason-lspconfig.nvim", dependencies = { "mason.nvim" } },
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "mason.nvim", "mfussenegger/nvim-dap" },
    config = function()
      require("mason-nvim-dap").setup({
        ensure_installed = { "python", "delve" },
        -- FIX: this was `true`, which raced with ensure_installed above and
        -- caused "Package is already installing". Both settings call mason's
        -- install() independently and only check "is it installed yet" (not
        -- "is an install already running"). Since nvim-dap's own config()
        -- already registers the python/go adapters before this plugin loads
        -- (it's a dependency), automatic_installation saw those adapters and
        -- tried to install debugpy at the same moment ensure_installed did;
        -- the second of the two calls hit mason's own "already installing"
        -- assertion. ensure_installed alone already installs exactly what's
        -- listed above, so automatic_installation is redundant here anyway.
        automatic_installation = false,
      })
    end,
  },

  -- ── LSP: nvim-cmp-lsp capabilities (explicit, loaded before lspconfig) ─────
  -- FIX: cmp-nvim-lsp must load before lspconfig to avoid race condition where
  -- lspconfig's BufReadPre fires before nvim-cmp's InsertEnter loads cmp_nvim_lsp.
  { "hrsh7th/cmp-nvim-lsp", lazy = true },

  -- ── LSP: LSPCONFIG ─────────────────────────────────────────────────────────
  -- FIX: require('lspconfig').<server>.setup{} (the pattern this section used
  -- to use) is deprecated -- it now prints a warning on every startup and is
  -- scheduled for hard removal in nvim-lspconfig v3.0.0, in favor of Neovim's
  -- own native vim.lsp.config()/vim.lsp.enable() (built in since 0.11).
  -- nvim-lspconfig is still listed as a dependency below -- it's not going
  -- away, it just now ships its server configs as plain lsp/*.lua files that
  -- vim.lsp.config reads automatically, rather than a require('lspconfig')
  -- "framework" you call .setup() on.
  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason-lspconfig.nvim", "hrsh7th/cmp-nvim-lsp" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- '*' applies to every server; the per-server calls below merge on top
      -- of it (confirmed: vim.lsp.config.html ends up with both the custom
      -- filetypes AND the inherited capabilities from '*').
      vim.lsp.config("*", { capabilities = capabilities })
      vim.lsp.config("html", { filetypes = { "php", "html", "css" } })
      vim.lsp.config("cssls", { filetypes = { "php", "html", "css" } })

      -- FIX: on_attach is an nvim-lspconfig-only concept; its native
      -- replacement is an LspAttach autocmd.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          local o = { buffer = ev.buf, noremap = true, silent = true }
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
          if client and vim.lsp.inlay_hint and client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
            vim.keymap.set("n", "<leader>lh", function()
              vim.lsp.inlay_hint.enable(
                not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }),
                { bufnr = ev.buf }
              )
            end, { buffer = ev.buf, desc = "Toggle inlay hints" })
          end
        end,
      })

      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls", "pyright", "clangd", "ts_ls", "rust_analyzer",
          "phpactor", "html", "cssls", "intelephense", "tailwindcss",
          "bashls", "dockerls", "jsonls", "yamlls",
        },
        -- FIX: replaces the old setup_handlers() loop below it -- mason-lspconfig
        -- now calls vim.lsp.enable() on every installed server for you.
        automatic_enable = true,
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
        format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
      })
      vim.keymap.set({ "n", "v" }, "<leader>lf", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
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

vim.list_extend(plugins, require("plugins.starter"))

-- ============================================================================
--  GLOBAL KEYMAPS
-- ============================================================================

-- ============================================================================
--  BOOTSTRAP PLUGINS
-- ============================================================================
require("lazy").setup(plugins, {
  root = plugin_root,
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
  headless = {
    process = true,
    log     = true,
    task    = true,
    colors  = false,
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
