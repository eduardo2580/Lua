local autocmd = vim.api.nvim_create_autocmd

autocmd("VimEnter", {
  callback = function()
    if #vim.fn.argv() > 0 then
      vim.schedule(function() pcall(vim.cmd, "Neotree reveal") end)
    end
  end,
})

autocmd("VimResized", {
  callback = function() vim.cmd("tabdo wincmd =") end,
})

autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})
