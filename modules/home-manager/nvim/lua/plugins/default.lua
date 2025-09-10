return {
    {
        "rafi/awesome-vim-colorschemes",
        lazy = false, -- make sure we load this during startup if it is your main colorscheme
        priority = 1000, -- make sure to load this before all the other start plugins
        dir = require("lazy-nix-helper").get_plugin_path("awesome-vim-colorschemes"),
        config = function()
            if vim.fn.empty("$TMUX") then
                if vim.fn.has("nvim") then
                    vim.cmd("let $NVIM_TUI_ENABLE_TRUE_COLOR=1")
                end
                if vim.fn.has("termguicolors") then
                    vim.opt.termguicolors = true
                end
            end
            vim.cmd([[
            syntax enable
            colorscheme one
        ]])
        end,
    },
    {
        "f-person/auto-dark-mode.nvim",
        lazy = false,
        dir = require("lazy-nix-helper").get_plugin_path("auto-dark-mode.nvim"),
    },
    {
        "nvim-lualine/lualine.nvim",
        lazy = false,
        opts = {
            options = { theme = "onedark" },
        },
        dir = require("lazy-nix-helper").get_plugin_path("lualine.nvim"),
        dependencies = {
            {
                "nvim-tree/nvim-web-devicons",
                dir = require("lazy-nix-helper").get_plugin_path("nvim-web-devicons"),
            },
        },
    },
    {
        "nmac427/guess-indent.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("guess-indent.nvim"),
    },
    {
        "tpope/vim-sensible",
        dir = require("lazy-nix-helper").get_plugin_path("vim-sensible"),
    },
    {
        "tpope/vim-fugitive",
        dir = require("lazy-nix-helper").get_plugin_path("vim-fugitive"),
    },
    {
        "tpope/vim-commentary",
        dir = require("lazy-nix-helper").get_plugin_path("vim-commentary"),
    },
    {
        "machakann/vim-sandwich",
        dir = require("lazy-nix-helper").get_plugin_path("vim-sandwich"),
    },
    {
        "LnL7/vim-nix",
        dir = require("lazy-nix-helper").get_plugin_path("vim-nix"),
    },
    {
        "NotAShelf/direnv.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("direnv.nvim"),
        opts = {
            -- Whether to automatically load direnv when entering a directory with .envrc
            autoload_direnv = false,

            -- Statusline integration
            statusline = {
                -- Enable statusline component
                enabled = false,
                -- Icon to display in statusline
                icon = "󱚟",
            },

            -- Keyboard mappings
            keybindings = {
                allow = "<Leader>da",
                deny = "<Leader>dd",
                reload = "<Leader>dr",
                edit = "<Leader>de",
            },
        },
    },
    {
        "francoiscabrol/ranger.vim",
        dir = require("lazy-nix-helper").get_plugin_path("ranger.vim"),
    },
}
