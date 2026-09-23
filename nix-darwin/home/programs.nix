{ config, pkgs, ... }:

{
  programs = {
    git = {
      enable = true;
      ignores = [ ".claude/settings.local.json" ];
      settings = {
        user.name = "Joey McKenzie";
        http.postBuffer = 1048576000;
        merge.conflictStyle = "zdiff3";
        init.defaultBranch = "main";
      };
    };

    difftastic = {
      enable = true;
      options = {
        background = "dark";
        display = "inline";
        color = "always";
      };
      git = {
        enable = true;
        mode = "both";
      };
    };

    gh = {
      enable = true;
      extensions = [
        pkgs.gh-dash
        pkgs.gh-stack
      ];
      settings = {
        version = "1";
        git_protocol = "https";
        prompt = "enabled";
        aliases = {
          co = "pr checkout";
        };
      };
    };

    broot = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        show_selection_mark = true;
        verbs = [
          {
            invocation = "edit";
            shortcut = "e";
            key = "ctrl-e";
            apply_to = "text_file";
            execution = "$EDITOR {file}";
            leave_broot = false;
          }
          {
            invocation = "create {subpath}";
            execution = "$EDITOR {directory}/{subpath}";
            leave_broot = false;
          }
          {
            invocation = "git_diff";
            shortcut = "gd";
            leave_broot = false;
            execution = "git difftool -y {file}";
          }
          {
            invocation = "backup {version}";
            key = "ctrl-b";
            leave_broot = false;
            auto_exec = false;
            execution = "cp -r {file} {parent}/{file-stem}-{version}{file-dot-extension}";
          }
          {
            invocation = "terminal";
            key = "ctrl-t";
            execution = "$SHELL";
            set_working_dir = true;
            leave_broot = false;
          }
        ];
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
      stdlib = ''
        eval "$(devenv direnvrc)"
      '';
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      # Yield Ctrl-R to atuin, which owns shell history.
      historyWidget.zsh.command = "";
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = false;
        aws.symbol = " ";
        buf.symbol = " ";
        bun.symbol = " ";
        c.symbol = " ";
        cpp.symbol = " ";
        cmake.symbol = " ";
        conda.symbol = " ";
        crystal.symbol = " ";
        dart.symbol = " ";
        deno.symbol = " ";
        directory.read_only = " 󰌾";
        docker_context.symbol = " ";
        elixir.symbol = " ";
        elm.symbol = " ";
        fennel.symbol = " ";
        fortran.symbol = " ";
        fossil_branch.symbol = " ";
        gcloud.symbol = "󱇶 ";
        git_branch.symbol = " ";
        git_commit.tag_symbol = "  ";
        golang.symbol = " ";
        gradle.symbol = " ";
        guix_shell.symbol = " ";
        haskell.symbol = " ";
        haxe.symbol = " ";
        hg_branch.symbol = " ";
        hostname.ssh_symbol = " ";
        java.symbol = " ";
        julia.symbol = " ";
        kotlin.symbol = " ";
        lua.symbol = " ";
        memory_usage.symbol = "󰍛 ";
        meson.symbol = "󰔷 ";
        nim.symbol = " ";
        nix_shell.symbol = " ";
        nodejs.symbol = " ";
        ocaml.symbol = " ";
        os.symbols = {
          Alpaquita = " ";
          Alpine = " ";
          AlmaLinux = " ";
          Amazon = " ";
          Android = " ";
          AOSC = " ";
          Arch = " ";
          Artix = " ";
          CachyOS = " ";
          CentOS = " ";
          Debian = " ";
          DragonFly = " ";
          Emscripten = " ";
          EndeavourOS = " ";
          Fedora = " ";
          FreeBSD = " ";
          Garuda = " ";
          Gentoo = " ";
          HardenedBSD = "󰞌 ";
          Illumos = " ";
          Kali = " ";
          Linux = " ";
          Mabox = " ";
          Macos = " ";
          Manjaro = " ";
          Mariner = " ";
          MidnightBSD = " ";
          Mint = " ";
          NetBSD = " ";
          NixOS = " ";
          Nobara = " ";
          OpenBSD = " ";
          openSUSE = " ";
          OracleLinux = "󰺡 ";
          Pop = " ";
          Raspbian = " ";
          Redhat = "󱄛 ";
          RedHatEnterprise = "󱄛 ";
          RockyLinux = " ";
          Redox = "󰀘 ";
          Solus = " ";
          SUSE = " ";
          Ubuntu = " ";
          Unknown = " ";
          Void = " ";
          Windows = "󰍲 ";
        };
        package.symbol = "󰏗 ";
        perl.symbol = " ";
        php.symbol = " ";
        pijul_channel.symbol = " ";
        pixi.symbol = "󰏗 ";
        python.symbol = " ";
        rlang.symbol = "󰟔 ";
        ruby.symbol = " ";
        rust.symbol = "󱘗 ";
        scala.symbol = " ";
        status.symbol = " ";
        swift.symbol = " ";
        xmake.symbol = " ";
        zig.symbol = " ";
      };
    };

    tealdeer = {
      enable = true;
      settings.updates.auto_update = true;
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    pay-respects = {
      enable = true;
      enableZshIntegration = true;
    };

    nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/.config/nix-darwin";
    };

    google-chrome = {
      enable = true;
      package = null; # app comes from the Homebrew cask; nixpkgs google-chrome is Linux-only
      extensions = [
        { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1Password
        { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
        { id = "lodbfhdipoipcjmlebjbgmmgekckhpfb"; } # Harper grammar checker
        { id = "cbaffpghpcbmgbnlpamegieokkpdlnih"; } # Inertia.js devtools
        { id = "gfbepnlhpkbgbkcebjnfhgjckibfdfkc"; } # FantasyPros
        { id = "fcoeoabgfenejglbffodgkkbkcdhcgfn"; } # Claude
      ];
    };

    vivaldi = {
      enable = true;
      package = null; # app comes from the Homebrew cask; nixpkgs vivaldi is Linux-only
      extensions = [
        { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1Password
        { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
        { id = "lodbfhdipoipcjmlebjbgmmgekckhpfb"; } # Harper grammar checker
        { id = "cbaffpghpcbmgbnlpamegieokkpdlnih"; } # Inertia.js devtools
      ];
    };
  };
}
