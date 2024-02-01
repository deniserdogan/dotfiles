return {
	"nvim-lualine/lualine.nvim",
	config = function()
		require("lualine").setup({
			options = {
				theme = "auto",
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {},
			},
		})
	end,
}
