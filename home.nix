{ config, pkgs, inputs, ... }:

{
  home.stateVersion = "26.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Example Home Manager / Claude Code or Codex config (~/.claude/mcp.json or similar)
  home.file.".claude/mcp.json".text = builtins.toJSON {
    mcpServers = {
      rea = {
        command = "${inputs.rea-flake.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/rea";
        args = [ "mcp" ];
      };
    };
  };
}
