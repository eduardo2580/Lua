local M = {}

local state = { buf = nil, win = nil, job_started = false }

local cfg = {
  cfg_file = nil,
  lss_file = nil,
  home = nil,
  width_ratio = 0.88,
  height_ratio = 0.88,
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
    root .. "/Downloads/Lynx/lynx2.9.3/lynx.exe",
    root .. "/Downloads/Lynx/lynx2.9.3/lynx",
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

local function python_executable()
  if vim.fn.executable("python3") == 1 then
    return "python3"
  elseif vim.fn.executable("python") == 1 then
    return "python"
  end
  return "python3"
end

local lss_support_cache = nil
local function lynx_supports_lss()
  if lss_support_cache ~= nil then
    return lss_support_cache
  end
  local cmd = lynx_command()
  if cmd == "" then
    lss_support_cache = false
    return false
  end
  local help_out = vim.fn.system({ cmd, "-help" })
  if type(help_out) == "string" and (help_out:match("%-lss") or help_out:match("%-LSS")) then
    lss_support_cache = true
  else
    lss_support_cache = false
  end
  return lss_support_cache
end

local ssl_support_cache = nil
local function lynx_supports_ssl()
  if ssl_support_cache ~= nil then
    return ssl_support_cache
  end
  local cmd = lynx_command()
  if cmd == "" then
    ssl_support_cache = false
    return false
  end
  local version_out = vim.fn.system({ cmd, "-version" })
  if type(version_out) == "string" then
    local upper = version_out:upper()
    if upper:match("SSL") or upper:match("TLS") or upper:match("GNUTLS") or upper:match("OPENSSL") or upper:match("MBEDTLS") then
      ssl_support_cache = true
    else
      ssl_support_cache = false
    end
  else
    ssl_support_cache = false
  end
  return ssl_support_cache
end

local function get_sandbox_dir()
  return config_root() .. "/Downloads/Lynx/sandbox"
end

local function ensure_sandbox()
  local sdir = get_sandbox_dir()
  if vim.fn.isdirectory(sdir) == 0 then
    vim.fn.mkdir(sdir, "p")
  end
end

local function url_to_cache_filename(url)
  local hash = vim.fn.sha256(url):sub(1, 16)
  local ext = ".html"
  if url:match("%.pdf$") or url:match("%.pdf%?") then
    ext = ".pdf"
  elseif url:match("%.json$") or url:match("%.json%?") then
    ext = ".json"
  elseif url:match("%.css$") or url:match("%.css%?") then
    ext = ".css.html"
  elseif url:match("%.txt$") or url:match("%.txt%?") then
    ext = ".txt"
  end
  local clean_name = url:gsub("^%w+://", ""):gsub("[^%w%.%-]", "_")
  if #clean_name > 30 then
    clean_name = clean_name:sub(1, 30)
  end
  return get_sandbox_dir() .. "/" .. clean_name .. "_" .. hash .. ext
end

local function format_css_as_html(raw_css, title)
  local escaped = raw_css:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>" .. (title:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) .. "</title>"
    .. "<style>"
    .. "body { font-family: monospace; background: #0f1419; color: #e6b450; padding: 1em; line-height: 1.4; }"
    .. "h2 { color: #36a3d9; border-bottom: 2px solid #36a3d9; padding-bottom: 4px; font-size: 1.2em; }"
    .. "pre { background: #151b23; color: #e6b450; padding: 1em; border-radius: 4px; white-space: pre-wrap; word-wrap: break-word; }"
    .. ".info { color: #27a7b0; margin-bottom: 1em; font-weight: bold; }"
    .. "</style></head><body>"
    .. "<h2>🎨 CSS 2.1 Stylesheet: " .. (title:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) .. "</h2>"
    .. "<div class='info'>[ Rendered with full CSS 2.1 support in Lynx Minimal Web Viewer ]</div>"
    .. "<pre><code>" .. escaped .. "</code></pre>"
    .. "</body></html>"
end

local function fetch_and_cache(url, force_reload)
  ensure_sandbox()
  local cache_path = url_to_cache_filename(url)
  if not force_reload and vim.fn.filereadable(cache_path) == 1 then
    return cache_path
  end

  -- Local file handling
  if vim.fn.filereadable(url) == 1 then
    if url:match("%.css$") then
      local f = io.open(url, "r")
      if f then
        local content = f:read("*a")
        f:close()
        local formatted_html = format_css_as_html(content, vim.fn.fnamemodify(url, ":t"))
        local out_f = io.open(cache_path, "w")
        if out_f then
          out_f:write(formatted_html)
          out_f:close()
          return cache_path
        end
      end
    end
    return url
  end

  local download_cmd = nil
  if vim.fn.executable("curl") == 1 then
    download_cmd = { "curl", "-sSL", "-o", cache_path, url }
  elseif vim.fn.executable("wget") == 1 then
    download_cmd = { "wget", "-q", "-O", cache_path, url }
  end

  if download_cmd then
    local _ = vim.fn.system(download_cmd)
    if vim.v.shell_error == 0 and vim.fn.filereadable(cache_path) == 1 and vim.fn.getfsize(cache_path) > 0 then
      if cache_path:match("%.json$") then
        local py_cmd = python_executable()
        local formatted = vim.fn.system({ py_cmd, "-m", "json.tool", cache_path })
        if vim.v.shell_error == 0 and formatted and formatted ~= "" then
          local f = io.open(cache_path, "w")
          if f then
            f:write("<!DOCTYPE html><html><head><title>JSON Document</title></head><body><pre>" .. vim.fn.escape(formatted, "<>") .. "</pre></body></html>")
            f:close()
          end
        end
      elseif cache_path:match("%.css") or url:match("%.css") then
        local f = io.open(cache_path, "r")
        if f then
          local content = f:read("*a")
          f:close()
          local formatted_html = format_css_as_html(content, url)
          local out_f = io.open(cache_path, "w")
          if out_f then
            out_f:write(formatted_html)
            out_f:close()
          end
        end
      end
      return cache_path
    end
  end
  return url
end

function M.clear_cache()
  ensure_sandbox()
  local sdir = get_sandbox_dir()
  local files = vim.fn.glob(sdir .. "/*", false, true)
  local count = 0
  for _, f in ipairs(files) do
    if vim.fn.delete(f) == 0 then
      count = count + 1
    end
  end
  vim.notify("Lynx sandbox cache cleared (" .. count .. " files deleted).", vim.log.levels.INFO)
end

function M.reload(url)
  local target_url = url or cfg.home
  if target_url:match("%.pdf$") or target_url:match("%.json$") or target_url:match("%.css$") or target_url:match("%.css%?") then
    local cached_file = fetch_and_cache(target_url, true)
    M.toggle(cached_file)
  else
    M.toggle(target_url)
  end
end

local function process_url(url)
  if not url or url == "" then
    return url
  end

  -- Cache static non-HTML resources like PDF/JSON/CSS for clean rendering
  if url:match("%.pdf$") or url:match("%.pdf%?")
     or url:match("%.json$") or url:match("%.json%?")
     or url:match("%.css$") or url:match("%.css%?")
     or (vim.fn.filereadable(url) == 1 and url:match("%.css$")) then
    return fetch_and_cache(url, false)
  end

  if not lynx_supports_ssl() then
    if url:match("^https://") then
      vim.schedule(function()
        vim.notify("Lynx build lacks OpenSSL/SSL support. Converting HTTPS URL to HTTP.", vim.log.levels.INFO)
      end)
      return (url:gsub("^https://", "http://"))
    end
  end
  return url
end

local function lynx_args(url)
  local args = { lynx_command() }
  if cfg.cfg_file and vim.fn.filereadable(cfg.cfg_file) == 1 then
    table.insert(args, "-cfg")
    table.insert(args, (cfg.cfg_file:gsub("\\", "/")))
  end
  if cfg.lss_file and vim.fn.filereadable(cfg.lss_file) == 1 and lynx_supports_lss() then
    table.insert(args, "-lss")
    table.insert(args, (cfg.lss_file:gsub("\\", "/")))
  end
  local final_url = process_url(url)
  if final_url and final_url ~= "" then
    table.insert(args, (final_url:gsub("\\", "/")))
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
    title = " qute-lynx ",
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
  cfg.lss_file = cfg.lss_file or config_root() .. "/Downloads/Lynx/lynx-nvim.lss"
  cfg.home = cfg.home or config_root() .. "/Downloads/Lynx/portal.html"

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
  vim.api.nvim_create_user_command("LynxClearCache", M.clear_cache, { desc = "Clear Lynx sandbox offline cache" })
  vim.api.nvim_create_user_command("LynxReload", function(args)
    M.reload(args.args ~= "" and args.args or nil)
  end, { nargs = "?", desc = "Reload current or specified URL from internet" })

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