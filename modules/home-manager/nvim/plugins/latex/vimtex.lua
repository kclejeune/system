-- VIMTEX SETTINGS
-- set vimtex default to latex syntax
vim.g.tex_flavor = "latex"
-- let g:vimtex_compiler_method = 'latexmk'
vim.g.vimtex_view_method = "skim"
vim.g.vimtex_quickfix_enabled = 0
-- compile on filesave
vim.cmd("autocmd! BufWritePost *.tex normal ,ll")
