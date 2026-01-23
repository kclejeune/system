return {
    "nvim-treesitter/nvim-treesitter",
    dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter"),
    opts = {
        sync_install = false,
        auto_install = false,
        highlight = {
            enable = true,

            disable = function(lang, buf)
                -- disable for languages with TS highlight issues
                local disabled_langs = {
                    csv = true,
                }
                if disabled_langs[lang] then
                    return true
                end

                -- disable for large files (1MB) that'll choke the treesitter parser
                local max_filesize = math.pow(1024, 2)
                local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                if ok and stats and stats.size > max_filesize then
                    return true
                end
                return false
            end,

            additional_vim_regex_highlighting = { "csv" },
        },
        incremental_selection = {
            enable = true,
            keymaps = {
                init_selection = "gnn",
                node_incremental = "grn",
                scope_incremental = "grc",
                node_decremental = "grm",
            },
        },
        indent = {
            enable = true,
        },
        textobjects = {
            select = {
                enable = true,
                keymaps = {
                    ["af"] = "@function.outer",
                    ["if"] = "@function.inner",
                    ["ac"] = "@class.outer",
                    ["ic"] = "@class.inner",
                },
            },
            move = {
                enable = true,
                goto_next_start = {
                    ["]m"] = "@function.outer",
                    ["]]"] = "@class.outer",
                },
                goto_next_end = {
                    ["]M"] = "@function.outer",
                    ["]["] = "@class.outer",
                },
                goto_previous_start = {
                    ["[m"] = "@function.outer",
                    ["[["] = "@class.outer",
                },
                goto_previous_end = {
                    ["[M"] = "@function.outer",
                    ["[]"] = "@class.outer",
                },
            },
            swap = {
                enable = true,
                swap_next = {
                    ["<leader>a"] = "@parameter.inner",
                },
                swap_previous = {
                    ["<leader>A"] = "@parameter.inner",
                },
            },
        },
    },
    config = function(_, opts)
        vim.filetype.add({
            extension = {
                gotmpl = "gotmpl",
                tmpl = "gotmpl",
                tpl = "gotmpl",
            },
        })
        require("nvim-treesitter.configs").setup(opts)
    end,
    dependencies = {
        {
            "nvim-treesitter/nvim-treesitter-textobjects",
            dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter-textobjects"),
        },
        {
            "nvim-treesitter/nvim-treesitter-context",
            dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter-context"),
        },
    },
}
