# /etc/nixos/home.nix
{ config, lib, pkgs, inputs, ... }:

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

  # Map every <src>/<dir>/<name> to both ~/.claude/skills and ~/.agents/skills
  skillsFrom = dir: builtins.listToAttrs (builtins.concatMap (name: [
    { name = ".claude/skills/${name}"; value.source = "${dir}/${name}"; }
    { name = ".agents/skills/${name}"; value.source = "${dir}/${name}"; }
  ]) (builtins.attrNames (builtins.readDir dir)));

  # Map every *.md in a dir to ~/.claude/<target>/<file>
  mdFilesFrom = dir: target: builtins.listToAttrs (map (f: {
    name = ".claude/${target}/${f}";
    value.source = "${dir}/${f}";
  }) (builtins.filter (f: lib.hasSuffix ".md" f)
    (builtins.attrNames (builtins.readDir dir))));

  # AgriciDaniel/claude-obsidian: skills/* + subagents (plugin hooks skipped:
  # they need CLAUDE_PLUGIN_ROOT, only set when installed as a plugin)
  claudeObsidian = skillsFrom "${inputs.claude-obsidian-src}/skills"
    // mdFilesFrom "${inputs.claude-obsidian-src}/agents" "agents";

  # eugeniughelbur/obsidian-second-brain: repo root is the skill (SKILL.md,
  # references/, scripts/); commands/*.md are Claude Code slash commands
  obsidianSecondBrain = {
    ".claude/skills/obsidian-second-brain".source = inputs.obsidian-second-brain-src;
    ".agents/skills/obsidian-second-brain".source = inputs.obsidian-second-brain-src;
  } // mdFilesFrom "${inputs.obsidian-second-brain-src}/commands" "commands";

  # Shared MCP servers for Claude Code and agy
  mcpConfig = {
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
in
{
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  # Make 'graphify' available in your terminal $PATH
  home.packages = [
    graphify
    omniroute
    inputs.thorn.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
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

  # agy (Antigravity CLI) skills: mirror everything Claude Code has in
  # ~/.claude/skills (flake-managed + manually installed) into agy's global
  # skills dir. agy skips symlinked skills and /nix/store paths, so these must
  # be real copies; a manifest tracks what we own so agy-only skills survive.
  home.activation.agySkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      src="$HOME/.claude/skills"
      dst="$HOME/.gemini/config/skills"
      manifest="$dst/.hm-managed"
      mkdir -p "$dst"
      if [[ -f "$manifest" ]]; then
        while IFS= read -r name; do
          [[ -n "$name" ]] && rm -rf "''${dst:?}/$name"
        done < "$manifest"
      fi
      : > "$manifest"
      for s in "$src"/*/; do
        name=$(basename "$s")
        [[ -f "$s/SKILL.md" ]] || continue  # skips e.g. Claude Desktop's `synced`
        ${pkgs.rsync}/bin/rsync -rL --chmod=u+rwX --exclude=.git "$s" "$dst/$name/"
        echo "$name" >> "$manifest"
      done
    fi
  '';

  # Configure Claude Code + agy MCP servers & AI skills declaratively
  home.file = {
    ".claude/mcp.json".text = builtins.toJSON mcpConfig;
    # agy global MCP servers (same set as Claude Code)
    ".gemini/config/mcp_config.json" = {
      text = builtins.toJSON mcpConfig;
      force = true; # replaces the empty file agy created
    };
    # agy (Antigravity CLI) global rules -> live symlink to the shared AGENTS.md
    ".gemini/config/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/nixos/AGENTS.md";

    # Learnharness
    ".claude/skills/learnharness".source =
    "${inputs.learnharness}/skills/learnharness";
    ".agents/skills/learnharness".source =
    "${inputs.learnharness}/skills/learnharness";

    # Ponytail (single skill)
    ".claude/skills/ponytail".source = "${inputs.ponytail-src}/skills/ponytail";
    ".agents/skills/ponytail".source = "${inputs.ponytail-src}/skills/ponytail";
  } // claudeSkills // genericSkills // claudeObsidian // obsidianSecondBrain;
}
