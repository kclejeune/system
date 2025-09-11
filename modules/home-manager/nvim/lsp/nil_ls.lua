return {
    settings = {
        formatting = {
            command = "alejandra",
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
