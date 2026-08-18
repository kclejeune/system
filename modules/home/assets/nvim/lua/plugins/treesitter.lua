-- nixpkgs ships the `main` rewrite branch: setup() only manages install
-- dirs, and highlight/indent must be enabled per-buffer via
-- vim.treesitter.start(). Parsers are nix-built and land on the rtp
-- through xdg.configFile."nvim/parser", so no install config is needed.
return {
    "nvim-treesitter/nvim-treesitter",
    dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter"),
    lazy = false,
    config = function()
        -- no jsonc grammar in nixpkgs; json5 is a superset (comments,
        -- trailing commas) so it highlights jsonc fine
        vim.treesitter.language.register("json5", "jsonc")
        vim.filetype.add({
            extension = {
                gotmpl = "gotmpl",
                tmpl = "gotmpl",
                tpl = "gotmpl",
            },
        })

        -- languages that fall back to vim regex syntax: csv has treesitter
        -- highlight issues; typescript/tsx render noticeably slower under
        -- the 0.12 async highlighter than regex, with little visual gain.
        -- Only highlighting is skipped — textobjects and treesitter-context
        -- still parse on demand.
        local disabled_langs = {
            csv = true,
        }

        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("treesitter-highlight", {}),
            callback = function(args)
                local lang = vim.treesitter.language.get_lang(args.match) or args.match
                if disabled_langs[lang] then
                    return
                end
                -- skip large files (1MB) that'll choke the treesitter parser
                local max_filesize = math.pow(1024, 2)
                local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
                if ok and stats and stats.size > max_filesize then
                    return
                end
                pcall(vim.treesitter.start, args.buf, lang)
            end,
        })
    end,
    dependencies = {
        {
            -- queries only (@function.outer etc.) for mini.ai's treesitter
            -- spec; the main branch has no plugin/ dir, so loading it has
            -- no side effects
            "nvim-treesitter/nvim-treesitter-textobjects",
            dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter-textobjects"),
        },
        {
            "nvim-treesitter/nvim-treesitter-context",
            dir = require("lazy-nix-helper").get_plugin_path("nvim-treesitter-context"),
        },
    },
}
