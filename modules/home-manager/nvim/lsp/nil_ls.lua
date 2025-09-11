return {
    settings = {
        formatting = {
            command = "alejandra",
        },
        nix = {
            binary = "nix",
            maxMemoryMB = 2560,
            flake = {
                autoArchive = false,
                autoEvalInputs = true,
                nixpkgsInputName = "nixpkgs",
            },
        },
    },
}
