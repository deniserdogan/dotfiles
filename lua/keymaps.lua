local map = vim.api.nvim_set_keymap
local default_opts = { noremap = true, silent = true }

-- Press jj fast to ESC
map("i", "jj", "<Esc>", { noremap = true })

-- Treesitter
map("n", "<leader>t", "<cmd>NvimTreeToggle<cr>", default_opts)
map("n", "<leader>g", "<cmd>NvimTreeClose<cr>", default_opts)

-- Buffer shortcuts
map("n", "<leader>w", "<cmd>w<cr>", default_opts)
map("n", "<leader>W", "<cmd>wa<cr>", default_opts)
map("n", "<leader>q", "<cmd>q<cr>", default_opts)
map("n", "<leader>!", "<cmd>q!<cr>", default_opts)
map("n", "<leader>W", "<cmd>wa<cr>", default_opts)
map("n", "<leader>db", "<cmd>bdelete<cr>", default_opts)

map("n", "<leader>bt", "<cmd>Telescope buffers<cr>", default_opts)
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", default_opts)
map("n", "<leader>fr", "<cmd>Telescope lsp_references<cr>", default_opts)
map("n", "<leader>fq", "<cmd>Telescope quickfix<cr>", default_opts)


-- Next/Prev Buffer
map("n", "<C-n>", ":bnext<CR>", default_opts)
map("n", "<C-p>", ":bprevious<CR>", default_opts)
