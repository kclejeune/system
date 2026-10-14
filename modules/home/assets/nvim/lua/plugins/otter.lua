-- LSP features (hover, completion, diagnostics, ...) for embedded code:
-- markdown code fences, nix strings the nvim-treesitter queries inject
-- (writeShellScript, `/* lua */` comments, ...) and mise task `run` strings
-- (after/queries/toml).
-- Embedded languages only get a server if one is installed, e.g. bashls.
return {
    "jmbuhr/otter.nvim",
    dir = require("lazy-nix-helper").get_plugin_path("otter.nvim"),
    lazy = true,
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "neovim/nvim-lspconfig",
    },
    opts = {},
    init = function()
        -- filetype -> extra gate; plain TOML has no embedded code, so only
        -- mise configs qualify
        local always = function()
            return true
        end
        local filetypes = {
            markdown = always,
            nix = always,
            toml = require("mise").is_config,
        }
        -- autocmd lives in init so otter only loads (via require) once a
        -- matching buffer is opened
        vim.api.nvim_create_autocmd("FileType", {
            pattern = vim.tbl_keys(filetypes),
            group = vim.api.nvim_create_augroup("otter-activate", {}),
            callback = function(args)
                if filetypes[args.match](args.buf) then
                    require("otter").activate()
                end
            end,
        })
    end,
}
