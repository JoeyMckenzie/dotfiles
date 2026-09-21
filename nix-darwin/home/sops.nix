{ config, ... }:

{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    secrets = {

      "intelephense-licence" = {
        path = "${config.home.homeDirectory}/intelephense/licence.txt";
      };

      "harlequin-config" = {
        path = "${config.home.homeDirectory}/.harlequin.toml";
      };

      "lazysql-config" = {
        path = "${config.home.homeDirectory}/.config/lazysql/config.toml";
      };

      "sqlit-config" = {
        path = "${config.home.homeDirectory}/.config/sqlit/connections.json";
      };

      "cliamp-config" = {
        path = "${config.home.homeDirectory}/.config/cliamp/config.toml";
      };

      "graphite-token" = {
        path = "${config.home.homeDirectory}/.config/graphite/user_config";
        mode = "0600";
      };

      "agentic-trading-key" = { };

      "filament-blueprint-key" = { };

      "zai-agent-trader-api-key" = { };

      "zai-general-purpose-api-key" = { };

      "typesafe-api-key" = { };

    };

    templates."secrets.zsh" = {
      path = "${config.home.homeDirectory}/.config/zsh/secrets.zsh";
      content = ''
        export AGENTIC_TRAGDING_KEY=${config.sops.placeholder."agentic-trading-key"}
        export ZAI_AGENT_TRADER_API_KEY=${config.sops.placeholder."zai-agent-trader-api-key"}
        export ZAI_GENERAL_PURPOSE_API_KEY=${config.sops.placeholder."zai-general-purpose-api-key"}
        export FILAMENT_BLUEPRINT_KEY=${config.sops.placeholder."filament-blueprint-key"}
        export TYPESAFE_API_KEY=${config.sops.placeholder."typesafe-api-key"}
      '';
    };
  };
}
