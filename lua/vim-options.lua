vim.opt.background = "dark"
vim.wo.number = true
vim.opt.relativenumber = true
vim.opt.smartindent = true
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set signcolumn=yes")
vim.g.mapleader = " "

local default_opts = { noremap = true, silent = true }

-- Navigate vim panes better
vim.keymap.set("n", "<c-k>", ":wincmd k<CR>")
vim.keymap.set("n", "<c-j>", ":wincmd j<CR>")
vim.keymap.set("n", "<c-h>", ":wincmd h<CR>")
vim.keymap.set("n", "<c-l>", ":wincmd l<CR>")

vim.keymap.set("v", "K", ":m '>-2<CR>gv=gv")
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- Buffer shortcuts
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", default_opts)
vim.keymap.set("n", "<leader>W", "<cmd>wa<cr>", default_opts)
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", default_opts)
vim.keymap.set("n", "<leader>!", "<cmd>q!<cr>", default_opts)
vim.keymap.set("n", "<leader>db", "<cmd>bdelete<cr>", default_opts)

-- Next/Prev Buffer
vim.keymap.set("n", "<C-n>", ":bnext<CR>", default_opts)
vim.keymap.set("n", "<C-p>", ":bprevious<CR>", default_opts)
vim.keymap.set("x", "<leader>p", '"_dP')

vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>")
