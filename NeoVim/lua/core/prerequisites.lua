local M = {}

local function lynx_path()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
  local local_candidates = {
    root .. "/Downloads/Lynx/native/lynx.exe",
    root .. "/Downloads/Lynx/native/lynx",
    root .. "/Downloads/Lynx/lynx2.9.3/bin/lynx.exe",
    root .. "/Downloads/Lynx/lynx2.9.3/bin/lynx",
  }
  for _, candidate in ipairs(local_candidates) do
    if vim.fn.executable(candidate) == 1 then return candidate end
  end
  local command = vim.fn.exepath("lynx")
  if command == "" then command = vim.fn.exepath("lynx.exe") end
  return command
end

local function notify_missing(items)
  if #items == 0 then return end

  vim.schedule(function()
    vim.notify(
      "Neovim prerequisites missing: " .. table.concat(items, ", ") .. ". Run :CheckPrerequisites for details.",
      vim.log.levels.WARN
    )
  end)
end

function M.check()
  local missing = {}
  local required_version = "0.9.1"
  local lynx_command = lynx_path()

  if vim.fn.has("nvim-" .. required_version) ~= 1 then
    missing[#missing + 1] = "Neovim " .. required_version .. "+"
  end
  if vim.fn.executable("git") ~= 1 then missing[#missing + 1] = "git" end
  if vim.fn.executable("rg") ~= 1 then missing[#missing + 1] = "ripgrep (rg)" end
  if vim.fn.executable(lynx_command) ~= 1 then
    missing[#missing + 1] = "Lynx (build Downloads/Lynx/lynx2.9.3 or install it on PATH)"
  end
  if vim.fn.executable("node") ~= 1 then missing[#missing + 1] = "Node.js" end
  if vim.fn.executable("npm") ~= 1 and vim.fn.executable("npm.cmd") ~= 1 then
    missing[#missing + 1] = "npm"
  end
  local has_c_compiler = vim.fn.executable("cl") == 1
    or vim.fn.executable("clang") == 1
    or vim.fn.executable("gcc") == 1
    or vim.fn.executable("cc") == 1
  if not has_c_compiler then
    missing[#missing + 1] = "C compiler (cl, clang, gcc, or cc) for Tree-sitter"
  end
  if vim.fn.executable("python") ~= 1 and vim.fn.executable("python3") ~= 1 then
    missing[#missing + 1] = "Python 3.8+"
  elseif vim.fn.has("python3") ~= 1 then
    missing[#missing + 1] = "Python package pynvim"
  end

  if vim.fn.has("win32") == 0 and vim.fn.has("mac") == 0 then
    local has_x_clipboard = vim.fn.executable("xclip") == 1
      or vim.fn.executable("xsel") == 1
    local has_wayland_clipboard = vim.fn.executable("wl-copy") == 1
      and vim.fn.executable("wl-paste") == 1
    if not has_x_clipboard and not has_wayland_clipboard then
      missing[#missing + 1] = "xclip, xsel, or wl-clipboard"
    end
  end

  notify_missing(missing)
  return missing
end

function M.setup()
  vim.api.nvim_create_user_command("CheckPrerequisites", function()
    local missing = M.check()
    if #missing == 0 then
      vim.notify("Neovim prerequisites are available.", vim.log.levels.INFO)
    end
  end, { desc = "Check Neovim prerequisites" })

  M.check()
end

return M