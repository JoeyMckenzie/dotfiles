{ ... }:

{
  imports = [
    ./claude-code.nix
    ./packages.nix
    ./programs.nix
    ./shell.nix
    ./sops.nix
    ./neovim
    ./terminal.nix
    ./tools.nix
    ./languages.nix
    ./pi.nix
    ./skills.nix
    ./worktrunk.nix
  ];

  home = {
    stateVersion = "24.11";

    shell.enableNushellIntegration = false;

    # home-manager master is 26.11, nixpkgs-unstable still self-reports as 26.05.
    # Silence the mismatch check until nixpkgs bumps its release label.
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;

  # XDG paths on Darwin — many CLI tools (lazygit, btop, ...) hardcode ~/.config regardless of OS.
  xdg.enable = true;
}
