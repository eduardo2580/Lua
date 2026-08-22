local opt = vim.opt

opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.autoindent = true
opt.termguicolors = true
opt.cursorline = true
opt.scrolloff = 10
opt.signcolumn = "yes"
opt.updatetime = 50
opt.timeoutlen = 300
opt.wrap = false
opt.splitbelow = true
opt.splitright = true
opt.ignorecase = true
opt.smartcase = true
opt.showmode = false
opt.backspace = "indent,eol,start"
opt.undofile = true
opt.iskeyword:append("-")

vim.diagnostic.config({
  virtual_text = false,
  float = { border = "rounded" },
})
