{ inputs, ... }:

{
  imports = [
    ./options.nix
    ./keymaps.nix
    ./ui.nix
    ./completion.nix
    ./lsp.nix
    ./treesitter.nix
    ./formatting.nix
    ./linting.nix
    ./git.nix
    ./octo.nix
    ./harpoon.nix
    ./neotest.nix
    ./dap.nix
    ./aerial.nix
    ./laravel.nix
    ./orgmode.nix
  ];

  programs.nixvim = {
    enable = true;

    # We set `inputs.nixvim.inputs.nixpkgs.follows = "nixpkgs"` in the flake, so
    # nixvim warns that its own pinned nixpkgs was overridden. Stating the
    # source explicitly is the documented way to acknowledge that and silence
    # the warning; the value is what the default already resolved to.
    nixpkgs.source = inputs.nixpkgs;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    colorschemes.tokyonight = {
      enable = true;
      settings = {
        style = "night";
        transparent = true;
        styles.sidebars = "transparent";
        styles.floats = "transparent";
      };
    };

    globals = {
      mapleader = " ";
      maplocalleader = ",";
    };
  };
}
