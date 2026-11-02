# /etc/nixos/home.nix
{ config, pkgs, inputs, ... }:

let
  graphify = pkgs.python3Packages.buildPythonApplication {
    pname = "graphify";
    version = "git";
    pyproject = true;

    src = inputs.graphify-src;

    build-system = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    dependencies = with pkgs.python3Packages; [
      networkx
      tree-sitter
      rich
      pydantic
      # Add any additional Python libraries Graphify references in pyproject.toml
    ];

    doCheck = false; # Skip test suite during build
  };
in
{
  home.stateVersion = "26.05";[cite: 2]
  programs.home-manager.enable = true;[cite: 2]

  # Make 'graphify' available in your terminal $PATH
  home.packages = [ graphify ];

  # Configure Claude Code MCP servers declaratively
  home.file.".claude/mcp.json".text = builtins.toJSON {
    mcpServers = {
      rea = {
        command = "${inputs.rea-flake.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/rea";[cite: 2]
        args = [ "mcp" ];[cite: 2]
      };
      graphify = {
        command = "${graphify}/bin/graphify";
        args = [ "mcp" ]; # Or the specific sub-command Graphify uses for its stdio MCP server
      };
    };
  };
}
