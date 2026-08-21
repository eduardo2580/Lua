local games = {
  { name = "Tetris", command = "Tetris", controls = "Arrows move/rotate, Down soft-drops, Space hard-drops" },
  { name = "Vim Be Good", command = "VimBeGood", controls = "Follow the on-screen motion challenges" },
  { name = "Minesweeper", command = "Nvimesweeper", controls = "Enter/x reveal, ! flag, ? mark, Space cycles marks" },
  { name = "Shenzhen Solitaire", command = "ShenzhenSolitaireNewGame", controls = "Use the on-screen card and stack commands" },
  { name = "Snake", command = "Snake", controls = "h/j/k/l steer; eat apples and avoid walls" },
  { name = "Sudoku", command = "Sudoku", controls = "Use the board mappings; gh opens help, gn starts a game" },
  { name = "Killer Sheep", command = "KillKillKill", controls = "Follow the on-screen prompts" },
  { name = "Blackjack", command = "BlackJackNewGame", controls = "j plays, k finishes, q quits" },
  { name = "Tower Defense", command = "TDStart", controls = "Upgrade with :UpgradeTower, :UpgradeGun, :UpgradeCannon, :UpgradeIce, :UpgradeMine" },
  { name = "Lichess Chess", command = "LichessFindGame", controls = "Use the chess buffer and its on-screen commands" },
}

local function help_lines()
  local lines = {
    "TERMINAL ARCADE",
    "",
    "Launch any game with :Games, or run its command directly.",
    "All games run inside Neovim; close the game buffer or use its quit key to return.",
    "",
    "GAMES",
  }

  for _, game in ipairs(games) do
    lines[#lines + 1] = string.format("%-22s :%-28s %s", game.name, game.command, game.controls)
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "HUB COMMANDS"
  lines[#lines + 1] = ":Games       Pick and launch a game"
  lines[#lines + 1] = ":GameHelp    Show this guide"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Terminal basics: :q returns to your shell when no game is active."
  return lines
end

local function show_help()
  vim.cmd("botright new")
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, help_lines())
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].filetype = "help"
  vim.wo[0].wrap = false
  vim.wo[0].number = false
  vim.wo[0].relativenumber = false
end

local function launch_game(game)
  vim.cmd(game.command)
end

vim.api.nvim_create_user_command("GameHelp", show_help, { desc = "Show terminal game controls" })
vim.api.nvim_create_user_command("Games", function()
  vim.ui.select(games, {
    prompt = "Launch game:",
    format_item = function(game)
      return string.format("%-22s %s", game.name, game.controls)
    end,
  }, function(game)
    if game then launch_game(game) end
  end)
end, { desc = "Launch a terminal game" })

vim.keymap.set("n", "<leader>vg", "<cmd>Games<CR>", { desc = "Game arcade" })
vim.keymap.set("n", "<leader>vh", "<cmd>GameHelp<CR>", { desc = "Game controls" })