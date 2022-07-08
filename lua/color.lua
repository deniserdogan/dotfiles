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

-- setup must be called before loading

-- set colorscheme
vim.cmd("colorscheme nordfox")

-- set changes *(set it after colorscheme)
vim.cmd("highlight CursorLine guibg=none")
vim.cmd("highlight EndOfBuffer guifg=#14191e guibg=bg")
