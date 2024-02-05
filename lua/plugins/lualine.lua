return {
	"nvim-lualine/lualine.nvim",
	config = function()
		require("lualine").setup({
			options = {
				theme = "auto",
				disabled_filetypes = { "alpha", "neo-tree" },
				tabline = {},
				winbar = {},
				inactive_winbar = {},
				extensions = {},
			},
		})
	end,
}
