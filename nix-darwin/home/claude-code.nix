{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.claude-code = {
    enable = true;

    settings = {
      hooks = {
        PostToolUse = [
          {
            matcher = "Edit|MultiEdit|Write";
            hooks = [
              {
                type = "command";
                command = "p=\"$(jq -r '.tool_input.file_path')\"; case \"$p\" in *.nix) nixfmt \"$p\" ;; esac";
              }
            ];
          }
        ];
      };

      model = "claude-opus-5-5[1m]";
      enabledPlugins = {
        "last30days@last30days-skill" = true;
        "understand-anything@understand-anything" = true;
      };
      extraKnownMarketplaces = {
        understand-anything = {
          source = {
            source = "github";
            repo = "Egonex-AI/Understand-Anything";
          };
        };
      };
      promptSuggestionEnabled = false;
      tui = "fullscreen";
      skipWorkflowUsageWarning = true;
      theme = "dark-ansi";
      editorMode = "vim";
    };
  };

  home.file."${config.home.homeDirectory}/.claude/settings.json".enable = lib.mkForce false;
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.claude/settings.json"
    managed=${config.home.file."${config.home.homeDirectory}/.claude/settings.json".source}
    run mkdir -p "$(dirname "$target")"
    [ -s "$target" ] || echo '{}' > "$target"

    # Compute outside `run` so a jq failure cannot truncate the live file;
    # only the swap into place is a tracked mutation.
    if ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$target" "$managed" > "$target.hm-merged"; then
      run mv "$target.hm-merged" "$target"
    else
      rm -f "$target.hm-merged"
      errorEcho "Merging Claude Code settings into $target failed; left it untouched"
    fi
  '';
}
