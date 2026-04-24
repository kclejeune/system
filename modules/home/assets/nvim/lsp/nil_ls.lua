return {
    settings = {
        formatting = {
            command = "nixfmt",
        },
        nix = {
            binary = "nix",
            maxMemoryMB = 2560,
            flake = {
                autoArchive = true,
                autoEvalInputs = true,
                nixpkgsInputName = "nixpkgs",
            },
        },
    },
}
