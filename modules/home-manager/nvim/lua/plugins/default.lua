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
        "stevearc/conform.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("conform.nvim"),
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        keys = {
            {
                -- Customize or remove this keymap to your liking
                "<C-i>",
                function()
                    require("conform").format({ async = true })
                end,
                mode = "",
                desc = "Format buffer",
            },
            {
                -- Customize or remove this keymap to your liking
                "<leader>fb",
                function()
                    require("conform").format({ async = true })
                end,
                mode = "",
                desc = "Format buffer",
            },
        },
        ---@module "conform"
        ---@type conform.setupOpts
        opts = {
            -- Map of filetype to formatters
            formatters_by_ft = {
                lua = { "stylua" },
                -- Conform will run multiple formatters sequentially
                go = { "goimports", "gofmt" },
                nix = { "alejandra", "nixfmt", stop_after_first = true },
                -- You can also customize some of the format options for the filetype
                rust = { "rustfmt", lsp_format = "fallback", stop_after_first = true },
                javascript = { "prettier", stop_after_first = true },
                typescript = { "prettier", stop_after_first = true },
                html = { "prettier", stop_after_first = true },
                -- You can use a function here to determine the formatters dynamically
                python = function(bufnr)
                    if require("conform").get_formatter_info("ruff_format", bufnr).available then
                        return { "ruff_format" }
                    else
                        return { "isort", "black" }
                    end
                end,
                -- Use the "*" filetype to run formatters on all filetypes.
                ["*"] = { "trim_whitespace" },
            },
            -- Set this to change the default values when calling conform.format()
            -- This will also affect the default values for format_on_save/format_after_save
            default_format_opts = {
                lsp_format = "fallback",
            },
            -- If this is set, Conform will run the formatter on save.
            -- It will pass the table to conform.format().
            -- This can also be a function that returns the table.
            format_on_save = {
                -- I recommend these options. See :help conform.format for details.
                lsp_format = "fallback",
                timeout_ms = 500,
            },
            -- If this is set, Conform will run the formatter asynchronously after save.
            -- It will pass the table to conform.format().
            -- This can also be a function that returns the table.
            format_after_save = {
                lsp_format = "fallback",
            },
            -- Set the log level. Use `:ConformInfo` to see the location of the log file.
            log_level = vim.log.levels.ERROR,
            -- Conform will notify you when a formatter errors
            notify_on_error = true,
            -- Conform will notify you when no formatters are available for the buffer
            notify_no_formatters = true,
        },
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
