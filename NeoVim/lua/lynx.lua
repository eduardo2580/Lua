local M = {}

local state = { buf = nil, win = nil, job_started = false }

local cfg = {
  cfg_file = nil,
  home = "https://duckduckgo.com/html/",
  width_ratio = 0.85,
  height_ratio = 0.85,
  border = "rounded",
}

local function config_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
end

local function lynx_command()
  local root = config_root()
  local local_candidates = {
    root .. "/Downloads/Lynx/native/lynx.exe",
    root .. "/Downloads/Lynx/native/lynx",
    root .. "/Downloads/Lynx/lynx2.9.3/bin/lynx.exe",
    root .. "/Downloads/Lynx/lynx2.9.3/bin/lynx",
  }
  for _, candidate in ipairs(local_candidates) do
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
  return vim.fn.exepath("lynx") ~= "" and vim.fn.exepath("lynx") or vim.fn.exepath("lynx.exe")
end

local function lynx_args(url)
  local args = { lynx_command() }
  if cfg.cfg_file and vim.fn.filereadable(cfg.cfg_file) == 1 then
    table.insert(args, "-cfg=" .. cfg.cfg_file)
  end
  if url and url ~= "" then
    table.insert(args, url)
  end
  return args
end

local function float_opts()
  local width = math.floor(vim.o.columns * cfg.width_ratio)
  local height = math.floor(vim.o.lines * cfg.height_ratio)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = cfg.border,
    title = " lynx ",
    title_pos = "center",
  }
end

local function start_job(url)
  local command = lynx_command()
  if command == "" then
    vim.notify("Lynx was not found. See Downloads/Lynx/README.md.", vim.log.levels.ERROR)
    return false
  end
  vim.fn.termopen(lynx_args(url), {
    cwd = config_root(),
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify("Lynx exited with code " .. code, vim.log.levels.WARN)
        end)
      end
    end,
  })
  state.job_started = true
  return true
end

local function open_float(url)
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    state.win = vim.api.nvim_open_win(state.buf, true, float_opts())
    if url and not state.job_started then
      start_job(url)
    end
    vim.cmd("startinsert")
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  state.win = vim.api.nvim_open_win(state.buf, true, float_opts())
  if not start_job(url or cfg.home) then
    vim.api.nvim_win_close(state.win, true)
    state.buf, state.win = nil, nil
    return
  end
  vim.cmd("startinsert")

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = state.buf,
    once = true,
    callback = function()
      state.buf, state.win, state.job_started = nil, nil, false
    end,
  })
end

function M.toggle(url)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_hide(state.win)
    state.win = nil
    return
  end
  open_float(url)
end

function M.split(url)
  local command = lynx_command()
  if command == "" then
    vim.notify("Lynx was not found. See Downloads/Lynx/README.md.", vim.log.levels.ERROR)
    return
  end
  vim.cmd("vsplit")
  vim.fn.termopen(lynx_args(url or cfg.home), { cwd = config_root() })
  vim.cmd("startinsert")
end

function M.gx()
  local word = vim.fn.expand("<cWORD>"):gsub("[,.);]+$", "")
  if word == "" then
    return
  end
  if word:match("^https?://") or word:match("^%w[%w%-]*%.%a%a+") then
    M.toggle(word:match("^https?://") and word or "https://" .. word)
  else
    M.toggle(cfg.home .. "?q=" .. vim.fn.escape(word, " "))
  end
end

function M.gopher(args)
  local target = args
  if target == "" then
    target = "gopher://gopher.floodgap.com:70/1"
  elseif not target:match("^gophers?://") then
    target = "gopher://" .. target
  end
  M.toggle(target)
end

function M.setup(opts)
  cfg = vim.tbl_deep_extend("force", cfg, opts or {})
  cfg.cfg_file = cfg.cfg_file or config_root() .. "/Downloads/Lynx/lynx.cfg"

  vim.api.nvim_create_user_command("Lynx", function(args)
    M.toggle(args.args ~= "" and args.args or nil)
  end, { nargs = "?", desc = "Toggle floating Lynx browser" })
  vim.api.nvim_create_user_command("LynxSplit", function(args)
    M.split(args.args ~= "" and args.args or nil)
  end, { nargs = "?", desc = "Open Lynx in a vertical split" })
  vim.api.nvim_create_user_command("LynxGopher", function(args)
    M.gopher(args.args)
  end, { nargs = "?", desc = "Open a Gopher URL in Lynx" })
  vim.api.nvim_create_user_command("LynxGx", M.gx, { desc = "Open URL under cursor in Lynx" })

  vim.keymap.set("n", "<leader>bb", M.toggle, { desc = "Toggle Lynx browser" })
  vim.keymap.set("n", "<leader>ww", M.toggle, { desc = "Open Lynx browser" })
  vim.keymap.set("n", "gx", M.gx, { desc = "Open link under cursor in Lynx" })

  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "term://*lynx*",
    callback = function(args)
      vim.keymap.set("t", "<C-\\><C-\\>", [[<C-\><C-n>]], { buffer = args.buf })
    end,
  })
end

return M