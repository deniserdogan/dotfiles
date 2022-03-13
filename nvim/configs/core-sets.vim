set encoding=utf8
set autochdir
set mouse=a
set number
set noswapfile
set scrolloff=9
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set autoindent
set fileformat=unix
set colorcolumn=80
set hidden
set cursorline
set signcolumn=yes
set cursorlineopt=number
set fillchars=fold:\ ,vert:\ǀ,eob:\ ,msgsep:‾
set termguicolors
set background=dark
filetype indent on
set guicursor=i-ci-ve:block,i:blinkwait100-blinkoff400-blinkon250-Cursor/lCursor
  \
autocmd FileType html setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType css setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType javascriptreact setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType javascript setlocal tabstop=2 shiftwidth=2 softtabstop=2
au FileType python let b:AutoPairs = AutoPairsDefine({"f'" : "'", "r'" : "'", "b'" : "'"})
