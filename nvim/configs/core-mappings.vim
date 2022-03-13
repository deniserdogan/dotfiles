let mapleader = " "

inoremap <silent><expr> <Tab>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<Tab>" :
      \ coc#refresh()

"cmd history nav
" cnoremap <C-p> <Up>
" cnoremap <C-n> <Down>
"rerender window with cleaning highlight search
map <C-n> :bn<cr>
map <C-p> :bp<cr>
"quickfix list
nnoremap <silent>[e :cp<Enter>
nnoremap <silent>]e :cn<Enter>
"save buffer
nnoremap <Leader>w :w!<Enter>
"save all buffers
nnoremap <Leader>W :wa<Enter>
"save and exit
nnoremap <silent><Leader>x :x<Enter>
"save and exit all 
nnoremap <silent><Leader>xa :xa<Enter>
"revert buffer
nnoremap <silent><Leader>e :e!<Enter>
"quit all
nnoremap <Leader>! :qa!<Enter>
"delete buffer & do not close window
nnoremap <silent><Leader>d :bp<bar>sp<bar>bn<bar>bd!<Enter>
"delete buffer & close window
nnoremap <silent><Leader>; :bd!<Enter>
"only one window
nnoremap <silent><Leader>o <C-w>o
"close window
nnoremap <silent><Leader>q <C-w>q
"show registers
nnoremap <Leader>r :reg<Enter>
" copy, cut and paste
vmap <C-c> "+y
vmap <C-x> "+c
vmap <C-v> c<ESC>"+p
imap <C-v> <ESC>"+pa
