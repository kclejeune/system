-- Consolidated mini.nvim modules. The suite ships every module in one
-- plugin; anything without a setup() call here stays inert (which is how
-- skipped modules like mini.pairs and mini.pick are "disabled").
return {
    "nvim-mini/mini.nvim",
    dir = require("lazy-nix-helper").get_plugin_path("mini.nvim"),
    lazy = false,
    config = function()
        require("mini.icons").setup()
        -- fzf-lua and other devicons consumers resolve to mini.icons
        MiniIcons.mock_nvim_web_devicons()

        local ai = require("mini.ai")
        ai.setup({
            custom_textobjects = {
                -- treesitter definitions matching the old af/if/ac/ic maps;
                -- queries come from nvim-treesitter-textobjects (query-only dep)
                f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
                c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
            },
        })

        -- same sa/sd/sr defaults as vim-sandwich
        require("mini.surround").setup()

        require("mini.operators").setup({
            -- the default `gr` prefix evicts the builtin LSP grn/grr/gra
            -- maps, which this config relies on
            replace = { prefix = "cr" },
        })

        require("mini.bracketed").setup()
        require("mini.diff").setup()
        require("mini.git").setup()

        local statusline = require("mini.statusline")
        statusline.setup({
            content = {
                active = function()
                    local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
                    local git = statusline.section_git({ trunc_width = 40 })
                    local diff = statusline.section_diff({ trunc_width = 75 })
                    local diagnostics = statusline.section_diagnostics({ trunc_width = 75 })
                    local lsp = statusline.section_lsp({ trunc_width = 75 })
                    local filename = statusline.section_filename({ trunc_width = 140 })
                    local fileinfo = statusline.section_fileinfo({ trunc_width = 120 })
                    local location = statusline.section_location({ trunc_width = 75 })
                    local search = statusline.section_searchcount({ trunc_width = 75 })
                    local ok, direnv = pcall(require, "direnv")
                    local direnv_status = ok and direnv.statusline() or ""
                    return statusline.combine_groups({
                        { hl = mode_hl, strings = { mode } },
                        { hl = "MiniStatuslineDevinfo", strings = { git, diff, diagnostics, lsp } },
                        "%<",
                        { hl = "MiniStatuslineFilename", strings = { filename } },
                        "%=",
                        { hl = "MiniStatuslineFileinfo", strings = { direnv_status, fileinfo } },
                        { hl = mode_hl, strings = { search, location } },
                    })
                end,
            },
        })

        local miniclue = require("mini.clue")
        miniclue.setup({
            triggers = {
                { mode = "n", keys = "<Leader>" },
                { mode = "x", keys = "<Leader>" },
                { mode = "n", keys = "g" },
                { mode = "x", keys = "g" },
                { mode = "n", keys = "'" },
                { mode = "n", keys = "`" },
                { mode = "n", keys = '"' },
                { mode = "x", keys = '"' },
                { mode = "i", keys = "<C-r>" },
                { mode = "c", keys = "<C-r>" },
                { mode = "n", keys = "<C-w>" },
                { mode = "n", keys = "z" },
                { mode = "x", keys = "z" },
                -- mini.surround
                { mode = "n", keys = "s" },
                { mode = "x", keys = "s" },
                -- mini.bracketed
                { mode = "n", keys = "[" },
                { mode = "n", keys = "]" },
            },
            clues = {
                miniclue.gen_clues.square_brackets(),
                miniclue.gen_clues.builtin_completion(),
                miniclue.gen_clues.g(),
                miniclue.gen_clues.marks(),
                miniclue.gen_clues.registers(),
                miniclue.gen_clues.windows(),
                miniclue.gen_clues.z(),
                { mode = "n", keys = "<Leader>a", desc = "+AI/Claude" },
                { mode = "n", keys = "<Leader>d", desc = "+direnv" },
                { mode = "n", keys = "<Leader>f", desc = "+find/format" },
            },
        })
    end,
}
