return {
    "ibhagwan/fzf-lua",
    -- icons come from mini.icons via MiniIcons.mock_nvim_web_devicons()
    dependencies = {
        {
            "nvim-treesitter/nvim-treesitter-context",
            dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter-context"),
        },
    },
    opts = {
        "max-perf",
        winopts = {
            preview = { default = "bat" },
            treesitter = true,
        },
        previewers = {
            bat = {
                cmd = "bat",
                args = "--color=always --style=changes",
            },
        },
        fzf_opts = {
            ["--border"] = "rounded",
            ["--preview"] = true,
        },
    },
    dir = require("lazy-nix-helper").get_plugin_path("fzf-lua"),
    keys = {
        {
            "<C-p>",
            function()
                return require("fzf-lua").files()
            end,
        },
        {
            "<leader>ff",
            function()
                return require("fzf-lua").files()
            end,
        },
        {
            "<C-g>",
            function()
                return require("fzf-lua").live_grep_native({ resume = true })
            end,
        },
        {
            "<leader>fg",
            function()
                return require("fzf-lua").live_grep_native({ resume = true })
            end,
        },
    },
}
