return {
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
            vim.lsp.enable("angularls")
            vim.lsp.enable("astro")
            vim.lsp.enable("autotools_ls")
            vim.lsp.enable("awk_ls")
            vim.lsp.enable("basedpyright")
            vim.lsp.enable("bashls")
            vim.lsp.enable("biome")
            vim.lsp.enable("cssls")
            vim.lsp.enable("dagger")
            vim.lsp.enable("diagnosticls")
            vim.lsp.enable("docker_compose_language_service")
            vim.lsp.enable("docker_language_server")
            vim.lsp.enable("html")
            vim.lsp.enable("jdtls")
            vim.lsp.enable("jsonls")
            vim.lsp.enable("lua_ls")
            vim.lsp.enable("nil_ls")
            vim.lsp.enable("nixd")
            vim.lsp.enable("protols")
            vim.lsp.enable("ruby_lsp")
            vim.lsp.enable("ruff")
            vim.lsp.enable("svelte")
            vim.lsp.enable("terraformls")
            vim.lsp.enable("texlab")
            vim.lsp.enable("textlsp")
            vim.lsp.enable("ts_ls")
            vim.lsp.enable("vue_ls")
            vim.lsp.enable("yamlls")
            vim.lsp.enable("zls")
            vim.lsp.completion.enable()
            vim.diagnostic.config({ virtual_text = true })
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if client and client:supports_method("textDocument/inlineCompletion") then
                        vim.lsp.inline_completion.enable(true)
                    end
                end,
            })
        end,
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
            -- {
            --     "bydlw98/blink-cmp-env",
            --     dir = require("lazy-nix-helper").get_plugin_path("blink-cmp-env"),
            -- },
            {
                "disrupted/blink-cmp-conventional-commits",
                dir = require("lazy-nix-helper").get_plugin_path("blink-cmp-conventional-commits"),
            },
        },
        opts = {
            keymap = {
                preset = "super-tab",
                ["<CR>"] = { "accept", "fallback" },
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
                    -- env = {
                    --     name = "Env",
                    --     module = "blink-cmp-env",
                    --     --- @type blink-cmp-env.Options
                    --     opts = {
                    --         item_kind = require("blink.cmp.types").CompletionItemKind.Variable,
                    --         show_braces = true,
                    --         show_documentation_window = true,
                    --     },
                    -- },
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
}
