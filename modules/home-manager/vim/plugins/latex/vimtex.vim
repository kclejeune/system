"" VIMTEX SETTINGS
"" set vimtex default to latex syntax
let g:tex_flavor = 'latex'
" let g:vimtex_compiler_method = 'latexmk'
let g:vimtex_view_method = 'skim'
let g:vimtex_quickfix_enabled = 0
"" compile on filesave
autocmd! BufWritePost *.tex normal ,ll
