-- Shared by the `is-mise?` treesitter predicate and otter activation so both
-- agree on which TOML buffers are mise configs.
local M = {}

---@param bufnr integer|nil
---@return boolean
function M.is_config(bufnr)
    local filepath = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr or 0))
    local filename = vim.fn.fnamemodify(filepath, ":t")
    return filename:match("^%.?mise.*%.toml$") ~= nil
        or filepath:match("/%.?mise/config%.toml$") ~= nil
        or filepath:match("/%.?mise/config%.local%.toml$") ~= nil
        or filepath:match("/%.?mise/config%.[^/]+%.toml$") ~= nil
        or filepath:match("/%.config/mise/mise%.toml$") ~= nil
        or filepath:match("/%.config/mise/mise%.local%.toml$") ~= nil
        or filepath:match("/%.?mise/conf%.d/[^/]+%.toml$") ~= nil
end

return M
