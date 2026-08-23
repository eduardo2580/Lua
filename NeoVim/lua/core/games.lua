local games = {
  {
    name = "Tetris",
    command = "Tetris",
    difficulty = "Easy to start",
    goal = "Clear complete rows before the stack reaches the top.",
    controls = "Left/Right move, Up rotates, Down soft-drops, Space hard-drops.",
    lesson = "Start with the arrow keys. Keep the stack low and leave a vertical well for the long I piece.",
    quit = "q or close the game buffer",
  },
  {
    name = "Minesweeper",
    command = "Nvimesweeper",
    difficulty = "Logic",
    goal = "Reveal every safe cell without opening a mine.",
    controls = "Move with h/j/k/l or arrows, Enter/x reveals, ! flags, ? marks, Space cycles marks.",
    lesson = "A number tells you how many mines touch it. Flag certain mines first, then use those flags to solve nearby numbers.",
    quit = "q or close the game buffer",
  },
  {
    name = "Snake",
    command = "Snake",
    difficulty = "Reflex",
    goal = "Eat food, grow longer, and survive as long as possible.",
    controls = "h/j/k/l or arrow keys steer; eat apples and avoid walls and your tail.",
    lesson = "Make wide turns and keep an escape route. Do not chase food into a corner when the snake is long.",
    quit = "q or close the game buffer",
  },
  {
    name = "Sudoku",
    command = "Sudoku",
    difficulty = "Logic",
    goal = "Fill every row, column, and 3x3 box with 1 through 9 once.",
    controls = "Use the board mappings; gh opens help, gn starts a game. Check the game buffer for the current mapping.",
    lesson = "Begin with rows, columns, or boxes that have one missing number. Pencil-mark candidates and revisit them after every placement.",
    quit = "q or close the game buffer",
  },
  {
    name = "Killer Sheep",
    command = "KillKillKill",
    difficulty = "Reflex",
    goal = "React to the targets and survive the increasingly fast waves.",
    controls = "Follow the on-screen prompts and use the keys shown by the game.",
    lesson = "Keep your eyes near the center of the play area and react to the prompt rather than guessing. Sound can be enabled by the plugin.",
    quit = "q or close the game buffer",
  },
  {
    name = "Blackjack",
    command = "BlackJackNewGame",
    difficulty = "Chance",
    goal = "Beat the dealer without going over 21.",
    controls = "Space/Enter/h hits, s/k/Tab stands, n/r starts again, and q/Esc quits.",
    lesson = "Cards 2-10 count face value, face cards count 10, and an ace counts 1 or 11. Stand on a strong total and avoid busting.",
    quit = "q or :BlackJackQuit",
  },
}

local state = { buffer = nil, window = nil, index = 1, filter = "", view = "menu" }

local function visible_games()
  local result = {}
  local needle = state.filter:lower()
  for _, game in ipairs(games) do
    if needle == "" or game.name:lower():find(needle, 1, true) then
      result[#result + 1] = game
    end
  end
  return result
end

local function close_hub()
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_win_close(state.window, true)
  end
  state.window, state.buffer = nil, nil
end

local open_hub

local function launch_game(game)
  close_hub()
  local ok, error_message = pcall(vim.cmd, game.command)
  if not ok then
    vim.notify("Could not launch " .. game.name .. ": " .. error_message, vim.log.levels.ERROR)
    open_hub()
  end
end

local function render()
  if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then return end
  local lines = {}
  local selected = visible_games()[state.index]
  if state.view == "help" and selected then
    lines = {
      "GAME GUIDE: " .. selected.name,
      "",
      "GOAL",
      selected.goal,
      "",
      "HOW TO PLAY",
      selected.lesson,
      "",
      "CONTROLS",
      selected.controls,
      "",
      "WHEN FINISHED",
      selected.quit,
      "",
      "Press b to return to the arcade, Enter to launch, or q to close.",
    }
  else
    lines = {
      "TERMINAL ARCADE",
      "",
      "Select a game with j/k or the arrow keys, then press Enter to play.",
      "Press h for a lesson, / to filter, r for a random game, or q to close.",
      "",
      string.format("GAMES%s", state.filter ~= "" and "  [filter: " .. state.filter .. "]" or ""),
    }
    for index, game in ipairs(visible_games()) do
      lines[#lines + 1] = string.format("%s %-24s %-16s %s", index == state.index and ">" or " ", game.name, game.difficulty, game.goal)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "GameHelp opens this guide. Direct commands remain available, too."
  end
  vim.bo[state.buffer].modifiable = true
  vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
  vim.bo[state.buffer].modifiable = false
  vim.api.nvim_buf_set_name(state.buffer, "Terminal Arcade")
end

open_hub = function()
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_set_current_win(state.window)
    render()
    return
  end
  state.buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buffer].buftype = "nofile"
  vim.bo[state.buffer].bufhidden = "wipe"
  vim.bo[state.buffer].swapfile = false
  local width = math.min(110, math.max(70, vim.o.columns - 8))
  local height = math.min(30, math.max(18, vim.o.lines - 8))
  state.window = vim.api.nvim_open_win(state.buffer, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Terminal Arcade ",
    title_pos = "center",
  })
  vim.wo[state.window].cursorline = true
  vim.wo[state.window].wrap = false
  vim.wo[state.window].number = false
  vim.keymap.set("n", "q", close_hub, { buffer = state.buffer, desc = "Close arcade" })
  vim.keymap.set("n", "<Esc>", close_hub, { buffer = state.buffer, desc = "Close arcade" })
  vim.keymap.set("n", "j", function() state.index = math.min(#visible_games(), state.index + 1); render() end, { buffer = state.buffer })
  vim.keymap.set("n", "k", function() state.index = math.max(1, state.index - 1); render() end, { buffer = state.buffer })
  vim.keymap.set("n", "<Down>", function() state.index = math.min(#visible_games(), state.index + 1); render() end, { buffer = state.buffer })
  vim.keymap.set("n", "<Up>", function() state.index = math.max(1, state.index - 1); render() end, { buffer = state.buffer })
  vim.keymap.set("n", "<CR>", function()
    local selected = visible_games()[state.index]
    if selected then launch_game(selected) end
  end, { buffer = state.buffer, desc = "Launch selected game" })
  vim.keymap.set("n", "h", function() state.view = "help"; render() end, { buffer = state.buffer, desc = "Read selected game guide" })
  vim.keymap.set("n", "b", function() state.view = "menu"; render() end, { buffer = state.buffer, desc = "Back to game list" })
  vim.keymap.set("n", "/", function()
    local input = vim.fn.input("Filter games: ", state.filter)
    state.filter, state.index = input, 1
    render()
  end, { buffer = state.buffer, desc = "Filter games" })
  vim.keymap.set("n", "r", function()
    local available = visible_games()
    if #available > 0 then launch_game(available[math.random(#available)]) end
  end, { buffer = state.buffer, desc = "Launch a random game" })
  render()
end

vim.api.nvim_create_user_command("GameHelp", function() state.view = "help"; open_hub() end, { desc = "Show game lessons" })
vim.api.nvim_create_user_command("Games", function() state.view = "menu"; open_hub() end, { desc = "Open terminal arcade" })
vim.keymap.set("n", "<leader>vg", "<cmd>Games<CR>", { desc = "Open game arcade" })
vim.keymap.set("n", "<leader>vh", "<cmd>GameHelp<CR>", { desc = "Read game lessons" })
