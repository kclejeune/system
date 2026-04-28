return {
    "folke/snacks.nvim",
    dir = require("lazy-nix-helper").get_plugin_path("snacks.nvim"),
    -- Load before other plugins so `_G.Snacks` (set by snacks/init.lua) is
    -- ready before lazy submodules like `snacks.picker` schedule their
    -- deferred setup. Without this, picker/config/highlights.lua errors
    -- with "attempt to index global 'Snacks' (a nil value)".
    priority = 1000,
    lazy = false,
    opts = {},
}
