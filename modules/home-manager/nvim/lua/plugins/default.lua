return {
    {
        "navarasu/onedark.nvim",
        lazy = false,
        dir = require("lazy-nix-helper").get_plugin_path("onedark.nvim"),
        priority = 1000, -- make sure to load this before all the other start plugins
        opts = {},
        init = function()
            require("onedark").load()
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        lazy = false,
        opts = {
            options = { theme = "auto" },
            sections = {
                lualine_x = {
                    function()
                        return require("direnv").statusline()
                    end,
                    "encoding",
                    "fileformat",
                    "filetype",
                },
            },
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
        "numToStr/Comment.nvim",
        opts = {},
        dir = require("lazy-nix-helper").get_plugin_path("comment.nvim"),
    },
    {
        "kdheepak/lazygit.nvim",
        lazy = true,
        dir = require("lazy-nix-helper").get_plugin_path("lazygit.nvim"),
        cmd = {
            "LazyGit",
            "LazyGitConfig",
            "LazyGitCurrentFile",
            "LazyGitFilter",
            "LazyGitFilterCurrentFile",
        },
        -- setting the keybinding for LazyGit with 'keys' is recommended in
        -- order to load the plugin when the command is run for the first time
        keys = {
            { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
        },
    },
    {
        "lukas-reineke/indent-blankline.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("indent-blankline.nvim"),
        main = "ibl",
        ---@module "ibl"
        ---@type ibl.config
        opts = {},
    },
    {
        "nmac427/guess-indent.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("guess-indent.nvim"),
        opts = {},
    },
    {
        "windwp/nvim-autopairs",
        dir = require("lazy-nix-helper").get_plugin_path("nvim-autopairs"),
        opts = {},
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
        "numToStr/Comment.nvim",
        opts = {},
        dir = require("lazy-nix-helper").get_plugin_path("comment-nvim"),
    },
    {
        "machakann/vim-sandwich",
        dir = require("lazy-nix-helper").get_plugin_path("vim-sandwich"),
    },
    {
        "folke/which-key.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("which-key.nvim"),
        event = "VeryLazy",
        opts = {},
        keys = {
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = false })
                end,
                desc = "Buffer Local Keymaps (which-key)",
            },
        },
    },
    {
        "NotAShelf/direnv.nvim",
        lazy = false,
        dir = require("lazy-nix-helper").get_plugin_path("direnv.nvim"),
        main = "direnv",
        opts = {
            -- Whether to automatically load direnv when entering a directory with .envrc
            autoload_direnv = false,

            -- Statusline integration
            statusline = {
                -- Enable statusline component
                enabled = true,
                -- Icon to display in statusline
                icon = "󱚟",
            },
            keybindings = {
                allow = "<Leader>da",
                deny = "<Leader>dd",
                reload = "<Leader>dr",
                edit = "<Leader>de",
            },
        },
    },
    {
        "mikavilpas/yazi.nvim",
        lazy = true,
        dir = require("lazy-nix-helper").get_plugin_path("yazi.nvim"),
        version = "*", -- use the latest stable version
        event = "VeryLazy",
        dependencies = {
            {
                "nvim-lua/plenary.nvim",
                dir = require("lazy-nix-helper").get_plugin_path("plenary.nvim"),
                lazy = true,
            },
        },
        keys = {
            -- 👇 in this section, choose your own keymappings!
            {
                "<leader>-",
                mode = { "n", "v" },
                "<cmd>Yazi<cr>",
                desc = "Open yazi at the current file",
            },
            {
                -- Open in the current working directory
                "<leader>cw",
                "<cmd>Yazi cwd<cr>",
                desc = "Open the file manager in nvim's working directory",
            },
        },
        opts = {
            open_for_directories = true,
            keymaps = {
                show_help = "<f1>",
            },
        },
        -- if you use `open_for_directories=true`, this is recommended
        init = function()
            -- mark netrw as loaded so it's not loaded at all.
            --
            -- More details: https://github.com/mikavilpas/yazi.nvim/issues/802
            vim.g.loaded_netrwPlugin = 1
        end,
    },
}
