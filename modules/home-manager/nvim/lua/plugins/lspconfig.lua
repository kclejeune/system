return {
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        dir = require("lazy-nix-helper").get_plugin_path("nvim-lspconfig"),
        dependencies = {
            {
                "williamboman/mason.nvim",
                enable = require("lazy-nix-helper").mason_enabled(),
                dir = require("lazy-nix-helper").get_plugin_path("mason.nvim"),
            },
            {
                "williamboman/mason-lspconfig.nvim",
                enable = require("lazy-nix-helper").mason_enabled(),
                dir = require("lazy-nix-helper").get_plugin_path("mason-lspconfig.nvim"),
            },
        },
        config = function()
            vim.lsp.enable({
                "angularls",
                "astro",
                "autotools_ls",
                "awk_ls",
                "basedpyright",
                "bashls",
                "biome",
                "cssls",
                "dagger",
                "diagnosticls",
                "docker_compose_language_service",
                "docker_language_server",
                "html",
                "jdtls",
                "jsonls",
                "lua_ls",
                "nil_ls",
                -- "nixd",
                "protols",
                "ruby_lsp",
                "ruff",
                "svelte",
                "terraformls",
                "texlab",
                "textlsp",
                "ts_ls",
                "vue_ls",
                "yamlls",
                "zls",
            }, true)
            -- use tiny-inline-diagnostic.nvim for this
            vim.diagnostic.config({
                virtual_text = false,
                underline = true,
            })
            -- disable lsp highlight
            -- vim.api.nvim_create_autocmd("LspAttach", {
            --     callback = function(args)
            --         local client = vim.lsp.get_client_by_id(args.data.client_id)
            --         client.server_capabilities.semanticTokensProvider = nil
            --     end,
            -- })
        end,
    },
    {
        "rachartier/tiny-inline-diagnostic.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("tiny-inline-diagnostic.nvim"),
        event = "VeryLazy",
        priority = 1000,
        opts = {
            show_source = {
                enabled = true,
            },
            multilines = {
                enabled = true,
                trim_whitespaces = true,
            },
        },
    },
    {
        "folke/lazydev.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("lazydev.nvim"),
        ft = "lua", -- only load on lua files
        opts = {
            library = {
                -- See the configuration section for more details
                -- Load luvit types when the `vim.uv` word is found
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
    {
        "saghen/blink.cmp",
        version = "1.*",
        dir = require("lazy-nix-helper").get_plugin_path("blink.cmp"),
        dependencies = {
            {
                "rafamadriz/friendly-snippets",
                dir = require("lazy-nix-helper").get_plugin_path("friendly-snippets"),
            },
            {
                "folke/lazydev.nvim",
                dir = require("lazy-nix-helper").get_plugin_path("lazydev.nvim"),
            },
            {
                "neovim/nvim-lspconfig",
                dir = require("lazy-nix-helper").get_plugin_path("nvim-lspconfig"),
            },
            {
                "bydlw98/blink-cmp-env",
                dir = require("lazy-nix-helper").get_plugin_path("blink-cmp-env"),
            },
            {
                "disrupted/blink-cmp-conventional-commits",
                dir = require("lazy-nix-helper").get_plugin_path("blink-cmp-conventional-commits"),
            },
        },
        opts = {
            keymap = {
                preset = "super-tab",
                ["<CR>"] = { "accept", "fallback" },
                ["<C-u>"] = { "scroll_signature_up", "fallback" },
                ["<C-d>"] = { "scroll_signature_down", "fallback" },
            },
            completion = {
                documentation = {
                    auto_show = false,
                },
                list = {
                    selection = {
                        preselect = function(ctx)
                            return not require("blink.cmp").snippet_active({ direction = 1 })
                        end,
                    },
                },
            },
            signature = {
                enabled = true,
                trigger = {
                    show_on_insert = true,
                    show_on_insert_on_trigger_character = true,
                },
            },
            sources = {
                -- add lazydev to your completion providers
                default = { "lazydev", "lsp", "path", "snippets", "buffer", "conventional_commits" },
                providers = {
                    lazydev = {
                        name = "LazyDev",
                        module = "lazydev.integrations.blink",
                        -- make lazydev completions top priority (see `:h blink.cmp`)
                        score_offset = 100,
                    },
                    env = {
                        name = "Env",
                        module = "blink-cmp-env",
                        --- @type blink-cmp-env.Options
                        opts = {
                            item_kind = require("blink.cmp.types").CompletionItemKind.Variable,
                            show_braces = true,
                            show_documentation_window = true,
                        },
                    },
                    conventional_commits = {
                        name = "Conventional Commits",
                        module = "blink-cmp-conventional-commits",
                        enabled = function()
                            return vim.bo.filetype == "gitcommit"
                        end,
                        ---@module 'blink-cmp-conventional-commits'
                        ---@type blink-cmp-conventional-commits.Options
                        opts = {}, -- none so far
                    },
                },
            },
        },
    },
    {
        "coder/claudecode.nvim",
        dir = require("lazy-nix-helper").get_plugin_path("claudecode.nvim"),
        dependencies = {
            {
                "folke/snacks.nvim",
                dir = require("lazy-nix-helper").get_plugin_path("snacks.nvim"),
            },
        },
        config = true,
        keys = {
            { "<leader>a", nil, desc = "AI/Claude Code" },
            { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
            { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
            { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
            { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
            { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
            { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
            { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
            {
                "<leader>as",
                "<cmd>ClaudeCodeTreeAdd<cr>",
                desc = "Add file",
                ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
            },
            -- Diff management
            { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
            { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
        },
    },
}
