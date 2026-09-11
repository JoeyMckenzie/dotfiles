{
  description = "Joey's nix-darwin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    claude-code.url = "github:sadjow/claude-code-nix";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    laravel-nvim = {
      url = "github:adalessa/laravel.nvim";
      flake = false;
    };

    # Agent skills vendored from upstream repos. home/skills.nix picks the
    # individual skill dirs out of each one; bump with `nix flake update <input>`.
    caveman-skills = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };

    claude-video-skills = {
      url = "github:bradautomates/claude-video";
      flake = false;
    };

    diagram-design-skills = {
      url = "github:cathrynlavery/diagram-design";
      flake = false;
    };

    gh-stack-skills = {
      url = "github:github/gh-stack";
      flake = false;
    };

    humanizer-skills = {
      url = "github:blader/humanizer";
      flake = false;
    };

    launchdarkly-skills = {
      url = "github:launchdarkly/ai-tooling";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    obsidian-skills = {
      url = "github:kepano/obsidian-skills";
      flake = false;
    };

    ponytail-skills = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    vercel-skills = {
      url = "github:vercel-labs/skills";
      flake = false;
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Don't follow nixpkgs — worktrunk pins its own (with matching rust-overlay
    # and crane setup).
    worktrunk.url = "github:max-sixty/worktrunk";

    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tuicr = {
      url = "github:agavra/tuicr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nix-darwin,
      home-manager,
      claude-code,
      nixvim,
      rust-overlay,
      git-hooks,
      ...
    }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};

      preCommitCheck = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          nixfmt-rfc-style.enable = true;
          statix.enable = true;
          deadnix.enable = true;
        };
      };

      mkSystem =
        {
          hostname,
          username,
          hostFile,
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit inputs username hostname; };
          modules = [
            inputs.lix-module.darwinModules.lixFromNixpkgs
            {
              # MinIO FOSS edition is in maintenance-only mode upstream and
              # nixpkgs gates it on knownVulnerabilities. The listed CVEs all
              # require internet-facing auth/replication/OIDC/LDAP — none of
              # which apply to our 127.0.0.1-bound dev S3 instance.
              nixpkgs.config.permittedInsecurePackages = [
                "minio-2025-10-15T17-29-55Z"
              ];

              nixpkgs.overlays = [
                rust-overlay.overlays.default
                inputs.herdr.overlays.default
                (final: prev: {
                  claude-code = claude-code.packages.${system}.claude-code;
                  # nixpkgs harlequin ships postgres + bigquery adapters but not
                  # mysql, and harlequin-mysql isn't in nixpkgs at all. Build the
                  # PyPI package locally and splice it into harlequin's deps so
                  # `harlequin -a mysql` works after every darwin-rebuild.
                  # sqlit's MySQL and MariaDB adapters both import pymysql,
                  # but nixpkgs only wires up mysql-connector-python — which
                  # sqlit treats as the deprecated connector, not a substitute.
                  # Without this every MySQL connection dies on the
                  # "Driver import failed / Package: PyMySQL" dialog.
                  sqlit-tui = prev.sqlit-tui.overridePythonAttrs (old: {
                    dependencies = old.dependencies ++ [ final.python3Packages.pymysql ];
                    # With pymysql present the foreign-key integration tests stop
                    # self-skipping and try to reach a live MySQL/Postgres, which
                    # the darwin build sandbox can actually see.
                    disabledTestPaths = old.disabledTestPaths ++ [
                      "tests/integration/test_foreign_keys.py"
                    ];
                  });
                  harlequin = prev.harlequin.overridePythonAttrs (old: {
                    dependencies = old.dependencies ++ [
                      (final.python3Packages.callPackage ./home/_pkgs/harlequin-mysql.nix { })
                    ];
                  });
                  # nixpkgs-unstable is parked on 391b592e (2026-08-20), 298
                  # commits shy of NixOS/nixpkgs@9da1a5ec6 "curl-impersonate:
                  # fix dylib install name on darwin". Until the channel moves,
                  # curl-impersonate 2.1.0 keeps upstream's @rpath install name,
                  # so curl-cffi's extension module records an @rpath reference
                  # with no LC_RPATH and dies at dlopen — taking yt-dlp and the
                  # whole home-manager generation with it. Drop this once the
                  # channel includes that commit.
                  curl-impersonate = prev.curl-impersonate.overrideAttrs (old: {
                    nativeBuildInputs = old.nativeBuildInputs ++ [
                      final.fixDarwinDylibNames
                    ];
                  });
                  # visidata's checkPhase runs the built `vd`, which on darwin
                  # resolves its config dir to $HOME/Library/Application Support
                  # and mkdir -p's it at startup. The sandbox HOME is the
                  # read-only /homeless-shelter, so vd dies in reloadMacros()
                  # before any test runs and all 168 of them "fail" for the same
                  # reason. pythonImportsCheck still covers the package.
                  visidata = prev.visidata.overridePythonAttrs (_: {
                    doCheck = false;
                  });
                })
              ];
            }
            ./darwin
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = { inherit inputs; };
                users.${username}.imports = [
                  nixvim.homeModules.nixvim
                  inputs.pi.homeModules.default
                  inputs.worktrunk.homeModules.default
                  inputs.sops-nix.homeManagerModules.sops
                  ./home
                ];
              };
            }
            hostFile
          ];
        };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      checks.${system}.pre-commit-check = preCommitCheck;

      devShells.${system}.default = pkgs.mkShell {
        inherit (preCommitCheck) shellHook;
        buildInputs = preCommitCheck.enabledPackages;
      };

      darwinConfigurations = {
        personal = mkSystem {
          hostname = "personal";
          username = "jmckenzie";
          hostFile = ./hosts/personal.nix;
        };
        work = mkSystem {
          hostname = "work";
          username = "joeymckenzie";
          hostFile = ./hosts/work.nix;
        };
      };
    };
}
