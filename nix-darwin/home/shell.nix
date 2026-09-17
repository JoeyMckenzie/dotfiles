{ config, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };

    sessionVariables = {
      XDG_CONFIG_HOME = "$HOME/.config";
      BUN_INSTALL = "$HOME/.bun";
      OBSIDIAN_VAULTS = "$HOME/vaults";
      LEFTHOOK = "0";
      # grok ships a self-updater that can't write to its read-only store path.
      GROK_DISABLE_AUTOUPDATER = "1";
    };

    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';

    shellAliases = {
      pa = "php artisan";
      sail = "sh $([ -f sail ] && echo sail || echo vendor/bin/sail)";
      sa = "./vendor/bin/sail";

      wip = "git commit -am 'chore: wip' && git push";
      yeet = "git commit -am 'chore: wip' --no-verify && git push --no-verify";

      lg = "lazygit";
      lzd = "lazydocker";
      cvim = "clear && nvim .";
      nv = "clear && nvim .";
      bl = "backlog";
      spf = "superfile";

      ls = "eza --icons --git --git-ignore";
      la = "eza -al --icons --git --git-ignore";
      ll = "eza -l --icons --git --git-ignore";
      cat = "bat";

      ccode = "claude";

      dv = "devenv";
      dvs = "devenv shell";
      dvu = "devenv up";
      dvt = "devenv test";

      devenv-orphans = ''ps -axo pid,ppid,command | rg -v "claude|rg" | awk "\$2==1 && /vite|php artisan|redis-server|caddy|mailpit/ {print}"'';

      caddy-reload = "sudo caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile";

      weather = "curl wttr.in/Redding";
    };

    initContent = ''
      # User dev-tool bin dirs — APPENDED so nix paths win
      path+=(
        "$HOME/bin"
        "$HOME/.codeium/windsurf/bin"
        "$HOME/.opencode/bin"
        "$HOME/go/bin"
        "$HOME/.composer/vendor/bin"
      )

      # Multi-arg commit functions (zsh aliases can't take positional args cleanly)
      gc()   { git commit -am "$*"; }
      gcy()  { git commit -am "$*" --no-verify; }
      gcp()  { git commit -am "$*" && git push; }
      gcpy() { git commit -am "$*" --no-verify && git push --no-verify; }

      # Bootstrap a bare-clone worktree project from a git URL.
      gcw() {
        local url="$1" name
        if [[ -z $url ]]; then
          print -u2 "usage: gcw <git-clone-url>"
          return 1
        fi
        name="''${url##*/}"
        name="''${name%.git}"
        mkdir -p "$name" && builtin cd "$name" || return 1
        git clone --bare "$url" .git && wt switch main
      }

      # Yazi with cwd-jump
      y() {
        local tmp="$(mktemp -t yazi-cwd.XXXXXX)" cwd
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d "" cwd < "$tmp"
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
      }

      # Kill whatever is listening on a port, then verify the port is free.
      # LISTEN-only on purpose: a bare `lsof -i tcp:3000` also matches clients
      # connected to that port, so filtering avoids killing e.g. the browser.
      killport() {
        local ok=$'\e[32m✓\e[0m'
        local bad=$'\e[31m✗\e[0m'
        local port="$1"

        if [[ -z $port ]]; then
          print -u2 "usage: killport <port>"
          return 1
        fi

        _kp_pids() { lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null; }

        local pids=($(_kp_pids))
        if (( ''${#pids} == 0 )); then
          printf "  %s port %s already free\n" "$ok" "$port"
          return 0
        fi

        # Show what's getting killed — a surprise match should be visible.
        ps -o pid=,comm= -p ''${pids} | sed 's/^/    /'

        kill ''${pids} 2>/dev/null
        sleep 1

        local survivors=($(_kp_pids))
        if (( ''${#survivors} )); then
          kill -9 ''${survivors} 2>/dev/null
          sleep 1
        fi

        local remaining=($(_kp_pids))
        if (( ''${#remaining} )); then
          printf "  %s port %s still in use\n" "$bad" "$port"
          return 1
        fi
        printf "  %s port %s freed\n" "$ok" "$port"
      }

      # Single source of truth for the nix-darwin launchd services we own.
      # Passes (scope, label, use_sudo) to the callback for each service.
      _nix_services_each() {
        local fn=$1 svc
        $fn system org.nixos.caddy sudo
        $fn system org.nixos.dnsmasq sudo
        local svcs=(mailpit mysql redis postgres minio rustfs)
        [[ "$(_nix_host)" == work ]] && svcs+=(opensearch)
        for svc in "''${svcs[@]}"; do
          $fn "gui/$UID" "org.nixos.$svc" ""
        done
      }

      # Post-rebuild health checks for nix-darwin launchd services
      nix-health() {
        local ok=$'\e[32m✓\e[0m'
        local bad=$'\e[31m✗\e[0m'
        local pending=$'\e[33m…\e[0m'

        # System daemons (caddy/dnsmasq) need sudo to query. Refresh the
        # timestamp once up front so `sudo -n` inside _nh_row doesn't silently
        # fail and falsely report them as "not loaded".
        sudo -v

        _nh_row() {
          local scope=$1 label=$2 use_sudo=$3 out state pid
          if [[ -n $use_sudo ]]; then
            out=$(sudo -n launchctl print "$scope/$label" 2>/dev/null)
          else
            out=$(launchctl print "$scope/$label" 2>/dev/null)
          fi
          if [[ -z $out ]]; then
            printf "  %s %-10s not loaded\n" "$bad" "$label"
            return
          fi
          state=$(print -r -- "$out" | rg '^[[:space:]]+state = ' | head -1 | sed -E 's/^[[:space:]]+state = //')
          pid=$(print -r -- "$out" | rg '^[[:space:]]+pid = ' | head -1 | awk '{print $3}')
          [[ -z $state ]] && state=unknown
          case $state in
            running)               printf "  %s %-10s pid %s\n" "$ok" "$label" "$pid" ;;
            *spawn*|waiting)       printf "  %s %-10s %s\n" "$pending" "$label" "$state" ;;
            *)                     printf "  %s %-10s %s\n" "$bad" "$label" "$state" ;;
          esac
        }

        print "\nservice health"
        print "──────────────"
        _nix_services_each _nh_row
        print
      }

      # Kickstart every managed launchd service, then show resulting health.
      # Uses `launchctl kickstart -k` which kills the running instance (if any)
      # and re-launches it.
      nix-restart() {
        local ok=$'\e[32m✓\e[0m'
        local bad=$'\e[31m✗\e[0m'

        # Refresh sudo once so kickstart prompts (if any) happen here rather
        # than mid-output, and the trailing nix-health call doesn't re-prompt.
        sudo -v

        _nr_kick() {
          local scope=$1 label=$2 use_sudo=$3 rc
          if [[ -n $use_sudo ]]; then
            sudo launchctl kickstart -k "$scope/$label" >/dev/null 2>&1; rc=$?
          else
            launchctl kickstart -k "$scope/$label" >/dev/null 2>&1; rc=$?
          fi
          if (( rc == 0 )); then
            printf "  %s %-10s restarted\n" "$ok" "$label"
          else
            printf "  %s %-10s kickstart failed (rc=%d)\n" "$bad" "$label" "$rc"
          fi
        }

        print "\nrestarting services"
        print "───────────────────"
        _nix_services_each _nr_kick
        nix-health
      }

      # Recover a system launchd daemon parked in launchd's throttle window
      # (`state = spawn scheduled`, usually after a boot-time EX_CONFIG/78 exit
      # when certs/network weren't ready). `kickstart -k` HANGS in this state;
      # only a clean bootout+bootstrap clears the throttle. Run the two steps
      # separately and check each — a compound `bootout; bootstrap` can leave
      # the service fully unloaded. Defaults to caddy.
      nix-unstick() {
        local ok=$'\e[32m✓\e[0m'
        local bad=$'\e[31m✗\e[0m'
        local label="''${1:-org.nixos.caddy}"
        local plist="/Library/LaunchDaemons/$label.plist"

        if [[ ! -f $plist ]]; then
          printf "  %s %s: no plist at %s\n" "$bad" "$label" "$plist"
          return 1
        fi

        sudo -v

        # bootout: tolerate "not loaded" (nothing to unload is fine).
        sudo launchctl bootout "system/$label" 2>/dev/null
        printf "  %s %-14s booted out\n" "$ok" "$label"

        # bootstrap; retry once via bootout if it's still partially loaded
        # (Input/output error / error 5).
        if ! sudo launchctl bootstrap system "$plist" 2>/dev/null; then
          sudo launchctl bootout "system/$label" 2>/dev/null
          if ! sudo launchctl bootstrap system "$plist" 2>/dev/null; then
            printf "  %s %-14s bootstrap failed\n" "$bad" "$label"
            return 1
          fi
        fi
        printf "  %s %-14s bootstrapped\n" "$ok" "$label"

        nix-health
      }

      # Map $USER to the darwinConfigurations key in flake.nix.
      # LocalHostName isn't reliable (DHCP can stamp it as MacBook-Pro-XXXX),
      # but the flake configs are already differentiated by username.
      _nix_host() {
        case "$USER" in
          jmckenzie)    print -r -- personal ;;
          joeymckenzie) print -r -- work ;;
          *)            print -r -- "$USER" ;;
        esac
      }

      drs() {
        sudo darwin-rebuild switch --flake "$HOME/.config/nix-darwin#$(_nix_host)" && nix-health
      }

      nds() {
        nh darwin switch "$HOME/.config/nix-darwin" -H "$(_nix_host)" && nix-health
      }

      # Bun completions
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      [ -f "$HOME/.config/zsh/secrets.zsh" ] && source "$HOME/.config/zsh/secrets.zsh"
    '';
  };

}
