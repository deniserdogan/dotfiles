local options = {
  autoindent = true,
  autoread = true,
  breakindent = true,
  clipboard = "unnamedplus",
  cmdheight = 0,
  completeopt = { "menuone", "noselect", "popup" },
  confirm = true,
  cursorline = true,
  expandtab = true,
  fillchars = {
    fold = " ",
    foldclose = "",
    foldopen = "",
    foldsep = " ",
  },
  foldenable = true,
  foldcolumn = "1",
  foldlevel = 99,
  foldlevelstart = 99,
  ignorecase = true,
  inccommand = "split",
  laststatus = 3,
  linebreak = true,
  list = true,
  listchars = {
    extends = "…",
    nbsp = "␣",
    precedes = "…",
    tab = "» ",
    trail = "·",
  },
  mouse = "a",
  number = true,
  pumheight = 12,
  pumblend = 0,
  relativenumber = true,
  scrolloff = 5,
  shiftround = true,
  shiftwidth = 2,
  shortmess = "filnxtToOFWIcC",
  showmode = false,
  sidescrolloff = 8,
  signcolumn = "yes:2",
  smartcase = true,
  smartindent = true,
  softtabstop = 2,
  splitbelow = true,
  splitkeep = "screen",
  splitright = true,
  smoothscroll = false,
  swapfile = false,
  tabstop = 2,
  termguicolors = true,
  timeoutlen = 400,
  undofile = true,
  undolevels = 10000,
  updatetime = 200,
  virtualedit = "block",
  wildmode = "longest:full,full",
  winblend = 0,
  winborder = "single",
  winminwidth = 5,
  wrap = false,
}

for name, value in pairs(options) do
  vim.opt[name] = value
end

vim.opt.diffopt:append({ "algorithm:histogram", "indent-heuristic", "linematch:60" })
vim.opt.formatoptions:remove({ "o" })

if vim.fn.executable("rg") == 1 then
  vim.opt.grepformat = "%f:%l:%c:%m"
  vim.opt.grepprg = "rg --vimgrep --smart-case --hidden --glob '!.git'"
end

-- Neovim's native EditorConfig integration remains authoritative.
vim.g.editorconfig = true
