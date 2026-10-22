{ config, pkgs, inputs, ... }:

{
  home.stateVersion = "26.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
