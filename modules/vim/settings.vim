" ###########################################
" KEYBINDINGS AND OTHER SETTINGS
" ###########################################

" General Vim settings
set number
set wrap
set encoding=utf-8
set wildmenu
set lazyredraw
set ruler
set tabstop=4
set shiftwidth=4
set showmatch
set expandtab
set softtabstop=4
set autoindent
set smartindent

" Keybindings
nmap j gj
nmap k gk

" Search Settings
" show search results while typing
set incsearch
" highlight search results while typing
set hlsearch

"" Auto Strip Trailing Spaces
fun! <SID>StripTrailingWhitespaces()
    let l = line(".")
    let c = col(".")
    %s/\s\+$//e
    call cursor(l, c)
endfun

" Apply to only certain files by default
" autocmd FileType c,cpp,java,php,ruby,python autocmd BufWritePre <buffer> :call <SID>StripTrailingWhitespaces()

" Apply to all files by default
autocmd BufWritePre * :call <SID>StripTrailingWhitespaces()

" use <tab> for trigger completion and navigate to the next complete item
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~ '\s'
endfunction