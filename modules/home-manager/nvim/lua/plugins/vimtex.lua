return {
    "lervag/vimtex",
    lazy = false, -- we don't want to lazy load VimTeX
    config = function()
        -- VimTeX configuration goes here, e.g.
        vim.g.vimtex_view_method = "zathura"
        -- VIMTEX SETTINGS
        -- set vimtex default to latex syntax
        vim.g.tex_flavor = "latex"
        -- let g:vimtex_compiler_method = 'latexmk'
        vim.g.vimtex_view_method = "skim"
        vim.g.vimtex_quickfix_enabled = 0
        -- compile on filesave
        vim.cmd("autocmd! BufWritePost *.tex normal ,ll")
    end,
    dir = require("lazy-nix-helper").get_plugin_path("vimtex"),
}
