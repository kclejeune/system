{...}: {
  programs.git = {
    userEmail = "exponent42@skiff.com";
    userName = "ldmsh";
    signing = {
      key = "exponent42@skiff.com";
      signByDefault = true;
    };
  };
}
