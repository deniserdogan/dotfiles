call plug#begin()
Plug 'preservim/nerdtree' " NerdTree
Plug 'tpope/vim-commentary' " For Commenting gcc & gc
Plug 'vim-airline/vim-airline' " Status bar
Plug 'ap/vim-css-color' " CSS Color Preview
Plug 'ryanoasis/vim-devicons' " Developer Icons
Plug 'vim-python/python-syntax' " Better Python syntax
Plug 'jiangmiao/auto-pairs' "AutoPairs
Plug 'preservim/tagbar' " Tagbar
Plug 'ap/vim-buftabline'
Plug 'zefei/vim-wintabs'
Plug 'rafi/awesome-vim-colorschemes'
Plug 'trapd00r/neverland-vim-theme'
Plug 'k4yt3x/ayu-vim-darker'
Plug 'ronwoch/hotline-vim'
Plug 'ethantrithon/elementary.vim'
Plug 'wuelnerdotexe/vim-enfocado'

" Language server
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'neovim/nvim-lspconfig' 
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'williamboman/nvim-lsp-installer'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'L3MON4D3/LuaSnip'

" File Managemant
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" JS
Plug 'yuezk/vim-js'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'grvcoelho/vim-javascript-snippets'
Plug 'alvan/vim-closetag'
Plug 'SirVer/ultisnips'
Plug 'mlaursen/vim-react-snippets'
call plug#end()
