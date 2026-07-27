vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.loader.enable()

require("config.options")
require("config.lazy")
require("config.diagnostics").setup()
require("config.autocmds").setup()
require("config.keymaps").setup()
require("config.commands").setup()
