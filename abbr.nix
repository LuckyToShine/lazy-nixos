# /etc/nixos/abbr.nix
{
  # Environment variables (like `export N="/etc/nixos"` in .bashrc)
  variables = {
    N = "/etc/nixos";
  };

  # Define your abbreviations in a standard Nix attribute set
  shellAliases = {
    # System shortcuts
    ls = "lsd";
    l  = "lsd -l";
    la = "lsd -a";
    lla = "lsd -la";
    lt = "lsd --tree";
    wled = "echo 1 > /sys/class/leds/*::scrolllock/brightness";
    
    # NixOS shortcuts
    nrs = "sudo nixos-rebuild switch";
    nfu = "cd /etc/nixos/ && sudo nix flake update && sudo nixos-rebuild switch -L";
    nsv = "nix store --verify --check-contents --repair";
 
    # Git shortcuts
    g = "git";
    gs = "git status";
    ga = "git add";
    gc = "git commit";
    gp = "git push";

    # IA voy
    cc  = "claude";
    ccd = "claude --dangerously-skip-permissions";
    agyd = "agy --dangerously-skip-permissions";
  };
}

