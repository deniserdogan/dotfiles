"GIT
nnoremap <silent> <Leader>gg :Git<Enter>
nnoremap <silent> <Leader>gc :Commits<Enter>
nnoremap <silent> <Leader>gb :Git blame<Enter>
nnoremap <silent> <Leader>gr :Gread<Enter>
nnoremap <silent> <Leader>gl :Git log<Enter>

" NERDTree
nnoremap <C-g> :NERDTreeFocus<CR>
nnoremap <C-y> :NERDTreeToggle<CR>
nnoremap <C-t> :NERDTree<CR>

" nnoremap <C-t> :NERDTreeToggle<CR>
autocmd BufEnter NERD_tree_* | execute 'normal R'
nnoremap <leader>b :ls<cr>:b<space>

" Find files using Telescope command-line sugar.
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

" FZF
nnoremap <silent> <Leader>b :Buffers<CR>
nnoremap <silent> <C-f> :Files<CR>
nnoremap <silent> <Leader>f :Rg<CR>
nnoremap <silent> <Leader>/ :BLines<CR>
nnoremap <silent> <Leader>' :Marks<CR>
nnoremap <silent> <Leader>g :Commits<CR>
nnoremap <silent> <Leader>H :Helptags<CR>
nnoremap <silent> <Leader>hh :History<CR>
nnoremap <silent> <Leader>h: :History:<CR>
nnoremap <silent> <Leader>h/ :History/<CR>

"COC
"main commands
nmap <silent>gd <Plug>(coc-definition)
nmap <Leader>cr <Plug>(coc-rename)
nmap <Leader>ca <Plug>(coc-codeaction)
nmap <silent>cf <Plug>(coc-format)
nmap <Leader>cc :CocCommand editor.action.pickColor<Enter>
nmap <silent>cy <Plug>(coc-type-definition)
nmap <leader>qf <Plug>(coc-fix-current)

"ShowDocumentation in functions.vim
noremap <silent>K :call ShowDocumentation()<Enter>
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)
vnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>

map <leader>t :TagbarToggle<CR>

"request window/popup
inoremap <silent><expr> <C-Space> coc#refresh()
"expand snippets
imap <C-l> <Plug>(coc-snippets-expand)
"select from menu by Enter
inoremap <silent><expr> <Enter> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<Enter>\<C-r>=coc#on_enter()\<Enter>"
