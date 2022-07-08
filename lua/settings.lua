local cmd = vim.cmd -- execute Vim commands

-- local exec = vim.api.nvim_exec -- execute Vimscript
local g = vim.g -- global variables
local opt = vim.opt -- global/buffer/windows-scoped options

-- essentials
opt.signcolumn = "yes"
opt.guicursor = "i-ci-ve:block,i:blinkwait100-blinkoff400-blinkon250-Cursor/lCursor"
opt.colorcolumn = "80" -- Разделитель на 80 символов
opt.cursorline = true -- Подсветка строки с курсором
opt.number = true -- Включаем нумерацию строк
opt.relativenumber = false -- Вкл. относительную нумерацию строк
opt.scrolloff = 9

-- opt.laststatus = 0
opt.undofile = true -- Возможность отката назад
opt.splitright = true -- vertical split вправо
opt.splitbelow = true -- horizontal split вниз
opt.clipboard = "unnamed"
-- opt.list = true
-- opt.listchars["eol"] = "↲"
-- hey

-- colors
opt.termguicolors = true --  24-bit RGB colors

-- tabs
cmd([[
filetype indent plugin on
syntax enable
]])
opt.expandtab = true -- use spaces instead of tabs
opt.shiftwidth = 4 -- shift 4 spaces when tab
opt.tabstop = 4 -- 1 tab == 4 spaces
opt.smartindent = true -- autoindent new lines
cmd([[au BufEnter * set fo-=c fo-=r fo-=o]])
-- remove line lenght marker for selected filetypes
cmd([[autocmd FileType text,markdown,html,xhtml,javascript setlocal cc=0]])
-- 2 spaces for selected filetypes
cmd([[
autocmd FileType html setlocal tabstop=2 shiftwidth=2 softtabstop=blinkon250
autocmd FileType css setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType javascriptreact setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType javascript setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType lua setlocal tabstop=2 shiftwidth=2 softtabstop=2
]])

-- Golang highlight
g["go_highlight_types"] = 1
g["go_highlight_build_constraints"] = 1
g["go_highlight_generate_tags"] = 1
g["go_highlight_variable_declarations"] = 1
g["go_highlight_variable_assignments"] = 1
g["go_highlight_functions"] = 1
g["go_highlight_function_calls"] = 1
g["go_highlight_operators"] = 1
g["go_highlight_extra_types"] = 1
g["go_highlight_fields"] = 1
g["go_highlight_function_parameters"] = 1
g["go_highlight_format_strings"] = 1
g["go_def_mapping_enabled"] = 0
