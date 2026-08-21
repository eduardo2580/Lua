return {
  {
    "LunarVim/bigfile.nvim",
    event = "BufReadPre",
    opts = { filesize = 2 },
  },
  {
    "szw/vim-maximizer",
    event = "VeryLazy",
    keys = {
      { "<leader>sm", "<cmd>MaximizerToggle<CR>", desc = "Maximize window" },
    },
  },
  {
    "diepm/vim-rest-console",
  },
}