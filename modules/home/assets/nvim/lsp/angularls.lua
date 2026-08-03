-- upstream lspconfig doesn't set this, so angularls attaches to any TS
-- buffer in single-file mode (root_dir falls back to cwd) and spawns its
-- embedded tsserver alongside ts_ls. Require a real Angular workspace
-- (angular.json / nx.json root marker) before starting.
return {
    workspace_required = true,
}
