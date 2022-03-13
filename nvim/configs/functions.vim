" use <tab> for trigger completion and navigate to the next complete item
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~ '\s'
endfunction

function NERDTreeToggle()
    NERDTreeTabsToggle
    if g:nerdtree_open == 1
        let g:nerdtree_open = 0
    else
        let g:nerdtree_open = 1
        wincmd p
    endif
endfunction

"     if 0 == argc()
"         NERDTree
"     end
" endfunction
" autocmd VimEnter * call StartUp()
" autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Use <c-space> to trigger completion.

if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

function! HasGit() abort
    let l:branch = fugitive#statusline()
    return len(l:branch) > 1
endfunction

function! CurrentGitBranch() abort
    if HasGit()
        let l:branch = split(fugitive#statusline(),'[()]')
        return remove(l:branch, 1)
    endif
    return ""
endfunction

function! GitStatus() abort
    if HasGit()
        let [a, m, r] = GitGutterGetHunkSummary()
        if (a == 0) && (m == 0) && (r == 0)
            return ""
        endif
        return printf('   +:%d ~:%d -:%d', a, m, r)
    endif
    return ""
endfunction

function! ShowDocumentation()
    if &filetype == 'vim'
        execute 'h '.expand('<cword>')
    elseif (coc#rpc#ready())
        call CocActionAsync('doHover')
    else
        execute '!' . &keywordprg . " " . expand('<cword>')
    endif
endfunction

" function! DiagnosticStatus() abort
"     let l:info = get(b:, 'coc_diagnostic_info', {})
"     if empty(info) | return '' | endif
"     let l:error = info['error']
"     let l:warning = info['warning']
"     let l:information = info['information']
"     let l:hint = info['hint']
"     if (l:error == 0) && (l:warning == 0) && (l:information == 0) && (l:hint == 0)
"         return ""
"     endif
"     return printf('w:%d e:%d h:%d i:%d', l:warning, l:error, l:hint, l:information)
" endfunction
