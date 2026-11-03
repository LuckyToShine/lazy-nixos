# /etc/nixos/home.nix
{ config, pkgs, inputs, ... }:

let
  graphify = pkgs.python3Packages.buildPythonApplication {
    pname = "graphifyy"; # PyPI name; binary is still `graphify`
    version = (builtins.fromTOML (builtins.readFile "${inputs.graphify-src}/pyproject.toml")).project.version;
    pyproject = true;

    src = inputs.graphify-src;

    build-system = with pkgs.python3Packages; [
      setuptools
      wheel
    ];

    dependencies = with pkgs.python3Packages; [
      networkx
      numpy
      rapidfuzz
      pyyaml
      tree-sitter
      tree-sitter-python
      tree-sitter-javascript
      tree-sitter-typescript
      tree-sitter-rust
      tree-sitter-c-sharp
      tree-sitter-bash
      tree-sitter-json
      # `mcp` extra, needed for `graphify mcp`
      mcp
      starlette
      anyio
    ] ++ (with pkgs.python3Packages.tree-sitter-grammars; [
      tree-sitter-go
      tree-sitter-java
      tree-sitter-groovy
      tree-sitter-c
      tree-sitter-cpp
      tree-sitter-ruby
      tree-sitter-kotlin
      tree-sitter-scala
      tree-sitter-php
      tree-sitter-swift
      tree-sitter-lua
      tree-sitter-zig
      tree-sitter-powershell
      tree-sitter-elixir
      tree-sitter-objc
      tree-sitter-julia
      tree-sitter-verilog
      tree-sitter-fortran
    ]);

    # nixpkgs grammar versions don't all match upstream's pins (kotlin, fortran, groovy)
    pythonRelaxDeps = true;

    doCheck = false; # Skip test suite during build
  };

  omniroute = pkgs.writeShellScriptBin "omniroute" ''
    exec ${pkgs.nodejs_22}/bin/npx -y omniroute@latest "$@"
  '';

  # Dynamically map all skills from addyosmani/agent-skills
  agentSkillNames = builtins.attrNames (builtins.readDir "${inputs.agent-skills-src}/skills");

  claudeSkills = builtins.listToAttrs (map (name: {
    name = ".claude/skills/${name}";
    value = { source = "${inputs.agent-skills-src}/skills/${name}"; };
  }) agentSkillNames);

  genericSkills = builtins.listToAttrs (map (name: {
    name = ".agents/skills/${name}";
    value = { source = "${inputs.agent-skills-src}/skills/${name}"; };
  }) agentSkillNames);
in
{
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  # Make 'graphify' available in your terminal $PATH
  home.packages = [
    graphify
    omniroute
  ];

  # OmniRoute autostart (NixOS-safe replacement for `omniroute autostart enable`,
  # which would hardcode GC-able /nix/store and npx-cache paths into the unit).
  systemd.user.services.omniroute = {
    Unit = {
      Description = "OmniRoute AI proxy router";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${omniroute}/bin/omniroute serve --no-open";
      Environment = [ "PATH=${pkgs.nodejs_22}/bin:/run/current-system/sw/bin" ];
      EnvironmentFile = "-%h/.omniroute/.env";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Configure Claude Code MCP servers & AI skills declaratively
  home.file = {
    ".claude/mcp.json".text = builtins.toJSON {
      mcpServers = {
        rea = {
          command = "${inputs.rea-flake.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/rea";
          args = [ "mcp" ];
        };
        graphify = {
          # MCP stdio server is `python -m graphify.serve [graph.json]` (default: ./graphify-out/graph.json)
          command = "${pkgs.python3.withPackages (_: [ (pkgs.python3Packages.toPythonModule graphify) ])}/bin/python";
          args = [ "-m" "graphify.serve" ];
        };
      };
    };

    # Ponytail (single skill)
    ".claude/skills/ponytail".source = "${inputs.ponytail-src}/skills/ponytail";
    ".agents/skills/ponytail".source = "${inputs.ponytail-src}/skills/ponytail";
  } // claudeSkills // genericSkills;
}
