require("nightfox").setup({
	options = {
		transparent = true, -- Disable setting background
		terminal_colors = true,
		styles = { -- Style to be applied to different syntax groups
			comments = "italic", -- Value is any valid attr-list value `:help attr-list`
			conditionals = "NONE",
			constants = "italic",
			functions = "NONE",
			keywords = "italic",
			numbers = "NONE",
			operators = "NONE",
			strings = "NONE",
			types = "italic",
			variables = "bold",
		},
	},
})

--[[ vim.g.tokyonight_style = "night"
vim.g.tokyonight_italic_comments = true
vim.g.tokyonight_italic_keywords = true
vim.g.tokyonight_transparent = true
vim.g.tokyonight_transparent_sidebar = true
vim.g.tokyonight_italic_functions = true
vim.g.tokyonight_sidebars = { "qf", "vista_kind", "terminal", "packer" }
 ]]

vim.cmd("colorscheme nordfox")

-- set changes after colorscheme decleration
vim.cmd("highlight CursorLine guibg=none")
vim.cmd("highlight EndOfBuffer guifg=#14191e guibg=bg")
vim.cmd("highlight LineNr guifg=#544d4c")
