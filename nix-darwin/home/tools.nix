_:

{
  programs = {
    btop.enable = true;
    lazygit = {
      enable = true;
      settings = {
        git.diffRenderers = [
          {
            colorArg = "always";
            type = "extDiff";
            command = "difft --color=always --display=inline";
          }
        ];
      };
    };

    lazydocker.enable = true;

    yazi = {
      enable = true;
      enableZshIntegration = false;
    };

  };

  xdg.configFile = {
    "abtop/config.toml".source = ./config/abtop.toml;
    "btop/btop.conf".source = ./config/btop.conf;
    "btop/themes/tokyonight_night.theme".source = ./config/btop-tokyonight-night.theme;
    "opencode/opencode.json".source = ./config/opencode.json;
    "herdr/config.toml".source = ./config/herdr.toml;
    "graphite/aliases".source = ./config/graphite-aliases;
    "superfile/config.toml".source = ./config/superfile-config.toml;
    "superfile/hotkeys.toml".source = ./config/superfile-hotkeys.toml;
  };
}
