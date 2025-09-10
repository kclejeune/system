return {
    "nvim-treesitter/nvim-treesitter",
    dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter"),
    dependencies = {
        {
            "nvim-treesitter/nvim-treesitter-refactor",
            dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter-refactor"),
        },
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
