vim.cmd([[packadd packer.nvim]])

return require("packer").startup(function(use)
	use("wbthomason/packer.nvim")

	-----------------------------------------------------------
	-- ПЛАГИНЫ ВНЕШНЕГО ВИДА
	-----------------------------------------------------------
	-- Цветовая схема
	use("EdenEast/nightfox.nvim")
	use("joshdick/onedark.vim")

	-----------------------------------------------------------
	-- НАВИГАЦИЯ
	-----------------------------------------------------------
	-- Файловый менеджер
	use({
		"kyazdani42/nvim-tree.lua",
		requires = "kyazdani42/nvim-web-devicons",
		config = function()
			require("nvim-tree").setup({
				actions = {
					open_file = {
						quit_on_open = true,
					},
				},
			})
		end,
	})
	-- Навигация внутри файла по классам и функциям
	use("majutsushi/tagbar")
	-- Замена fzf и ack
	use({
		"nvim-telescope/telescope.nvim",
		requires = { { "nvim-lua/plenary.nvim" } },
		config = function()
			require("telescope").setup({})
		end,
	})

	-----------------------------------------------------------
	-- LSP и автодополнялка
	-----------------------------------------------------------
	-- Highlight, edit, and navigate code using a fast incremental parsing library
	use("nvim-treesitter/nvim-treesitter")
	-- Collection of configurations for built-in LSP client
	use("neovim/nvim-lspconfig")
	use("williamboman/nvim-lsp-installer")
	-- Автодополнялка
	use("hrsh7th/nvim-cmp")
	use("hrsh7th/cmp-nvim-lsp")
	use("hrsh7th/cmp-buffer")
	use("saadparwaiz1/cmp_luasnip")
	--- Автодополнлялка к файловой системе
	use("hrsh7th/cmp-path")
	-- Snippets plugin
	use("L3MON4D3/LuaSnip")
	-- Formatting
	use("jose-elias-alvarez/null-ls.nvim")

	-----------------------------------------------------------
	-- HTML и CSS
	-----------------------------------------------------------
	-- Подсвечивает закрывающий и откры. тэг. Если, где-то что-то не закрыто, то не подсвечивает.
	use("idanarye/breeze.vim")
	-- Закрывает автоматом html и xml тэги. Пишешь <h1> и он автоматом закроется </h1>
	use("alvan/vim-closetag")
	-- Подсвечивает #ffffff
	use("ap/vim-css-color")
	-- JS/TS/JSX Syntax
	use("yuezk/vim-js")
	use("HerringtonDarkholme/yats.vim")
	use("maxmellon/vim-jsx-pretty")

	-----------------------------------------------------------
	-- GOLANG
	-----------------------------------------------------------
	use("fatih/vim-go")

	-----------------------------------------------------------
	-- РАЗНОЕ
	-----------------------------------------------------------
	-- 'Автоформатирование' кода для всех языков
	use("nvim-lua/popup.nvim")

	-- Обрамляет или снимает обрамление. Выдели слово, нажми S и набери <h1>
	use("tpope/vim-surround")

	-- Стартовая страница, если просто набрать vim в консоле
	use("mhinz/vim-startify")

	-- Комментирует по gc все, вне зависимости от языка программирования
	use({
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	})

	-- Обрамляет строку в теги по ctrl- y + ,
	use("mattn/emmet-vim")

	-- Закрывает автоматом скобки
	use("cohama/lexima.vim")

	-- lualine
	use({
		"nvim-lualine/lualine.nvim",
		requires = { "kyazdani42/nvim-web-devicons", opt = true },
		config = function()
			require("lualine").setup({
				options = { section_separators = "", component_separators = "" },
			})
		end,
	})
end)
