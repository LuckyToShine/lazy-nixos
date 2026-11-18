# /etc/nixos/abbr.nix
{
  # Environment variables (like `export N="/etc/nixos"` in .bashrc)
  variables = {
    N = "/etc/nixos";
    HISTTIMEFORMAT = "%F %T ";
  };

  # Define your abbreviations in a standard Nix attribute set
  shellAliases = {
    # System shortcuts
    ls = "lsd";
    l  = "lsd -l";
    la = "lsd -A";
    lla = "lsd -lA";
    lt = "lsd --tree";
    wled = "brightnessctl --device='*::scrolllock' set 1";
    timesh = "HISTTIMEFORMAT='%F %T' history";
    
    # NixOS shortcuts
    nrs = "sudo nixos-rebuild switch";
    gnrs = "cd /etc/nixos/ && sudo nixos-rebuild switch && git add . && git commit -m \"rebuild\" && git push";
    nfu = "cd /etc/nixos/ && sudo nix flake update && sudo nixos-rebuild switch -L";
    gnfu = "cd /etc/nixos/ && sudo nix flake update && sudo nixos-rebuild switch -L && git add . && git commit -m \"flake update\" && git push";
    nsv = "nix store --verify --check-contents --repair";
 
    # Tools
    n = "nvim";

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

