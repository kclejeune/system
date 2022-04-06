-- ###########################################
-- KEYBINDINGS AND OTHER SETTINGS
-- ###########################################

-- General Vim settings
vim.opt.number = true
vim.opt.wrap = true
vim.opt.encoding = "utf-8"
vim.opt.wildmenu = true
vim.opt.lazyredraw = true
vim.opt.ruler = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.showmatch = true
vim.opt.expandtab = true
vim.opt.softtabstop = 4
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.incsearch = true
vim.opt.hlsearch = true

vim.api.nvim_set_keymap("n", "j", "gj", {})
vim.api.nvim_set_keymap("n", "k", "gk", {})

vim.fn.stripTrailingWhitespace = function()
    local l = vim.fn.line(".")
    local c = vim.fn.col(".")
    vim.cmd("%s/\\s\\+$//e")
    vim.fn.cursor(l, c)
end

-- TODO: how to convert this?
vim.cmd([[
" Apply to only certain files by default
" autocmd FileType c,cpp,java,php,ruby,python autocmd BufWritePre <buffer> :call <SID>StripTrailingWhitespaces()

" Apply to all files by default
autocmd BufWritePre * :call StripTrailingWhitespaces()
]])
