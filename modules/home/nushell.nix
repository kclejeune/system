_: {
  flake.homeModules.nushell = _: {
    programs.nushell = {
      enable = true;
      loadSessionVariables = true;
    };
  };
}
