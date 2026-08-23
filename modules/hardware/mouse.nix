{
  config,
  lib,
  pkgs,
  ...
}: {
  services.keyd = {
    enable = true;
    keyboards.gamingMouse = {
      ids = ["04d9:fc30"];
      settings = {
        main = {
          mouse1 = "previoussong";
          mouse2 = "nextsong";
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    keyd
    playerctl
    evtest
    wev
  ];
}
