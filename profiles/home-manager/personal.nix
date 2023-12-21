{...}: {
  programs.git = {
    userEmail = "me@ldm.sh";
    userName = "ldmsh";
    signing = {
      key = "me@ldm.sh";
      signByDefault = true;
    };
  };
}
