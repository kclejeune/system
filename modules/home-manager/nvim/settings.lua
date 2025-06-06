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
vim.opt.smartindent = false
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.foldenable = false

function vim.fn.stripTrailingWhitespace()
    local l = vim.fn.line(".")
    local c = vim.fn.col(".")
    vim.cmd("%s/\\s\\+$//e")
    vim.fn.cursor(l, c)
end

-- strip all files by default
vim.cmd("autocmd BufWritePre * :lua vim.fn.stripTrailingWhitespace()")
