{
  pkgs,
  lib,
  username,
  hostname,
  ...
}:

let
  mysqlPkg = pkgs.mysql84;
  mysqlDataDir = "/Users/${username}/.local/share/mysql";
  mysqlSocket = "${mysqlDataDir}/mysql.sock";
  mysqlStart = pkgs.writeShellScript "mysql-start" ''
    set -eu
    DATADIR=${mysqlDataDir}
    mkdir -p "$DATADIR"
    if [ ! -d "$DATADIR/mysql" ]; then
      ${mysqlPkg}/bin/mysqld --initialize-insecure --datadir="$DATADIR"
    fi
    # MySQL 8 adds ONLY_FULL_GROUP_BY by default; the CDC backfill queries this
    # stack runs need it off, matching the target database's mode.
    exec ${mysqlPkg}/bin/mysqld \
      --datadir="$DATADIR" \
      --socket=${mysqlSocket} \
      --bind-address=127.0.0.1 \
      --port=3306 \
      --sql-mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
  '';

  redisDataDir = "/Users/${username}/.local/share/redis";
  redisStart = pkgs.writeShellScript "redis-start" ''
    set -eu
    DATADIR=${redisDataDir}
    mkdir -p "$DATADIR"
    exec ${pkgs.redis}/bin/redis-server \
      --bind 127.0.0.1 \
      --port 6379 \
      --dir "$DATADIR" \
      --databases 64 \
      --save 60 1000 \
      --appendonly no
  '';

  postgresPkg = pkgs.postgresql_17;
  postgresDataDir = "/Users/${username}/.local/share/postgres";
  postgresStart = pkgs.writeShellScript "postgres-start" ''
    set -eu
    DATADIR=${postgresDataDir}
    mkdir -p "$DATADIR"
    if [ ! -f "$DATADIR/PG_VERSION" ]; then
      ${postgresPkg}/bin/initdb \
        -D "$DATADIR" \
        --no-locale \
        --encoding=UTF8 \
        -A trust \
        -U ${username}
    fi
    exec ${postgresPkg}/bin/postgres \
      -D "$DATADIR" \
      -h 127.0.0.1 \
      -p 5432 \
      -k "$DATADIR"
  '';

  minioDataDir = "/Users/${username}/.local/share/minio";
  minioStart = pkgs.writeShellScript "minio-start" ''
    set -eu
    DATADIR=${minioDataDir}
    mkdir -p "$DATADIR"
    export MINIO_ROOT_USER=minioadmin
    export MINIO_ROOT_PASSWORD=minioadmin
    exec ${pkgs.minio}/bin/minio server \
      --address 127.0.0.1:9000 \
      --console-address 127.0.0.1:9001 \
      "$DATADIR"
  '';

  rustfsDataDir = "/Users/${username}/.local/share/rustfs";
  rustfsStart = pkgs.writeShellScript "rustfs-start" ''
    set -eu
    DATADIR=${rustfsDataDir}
    mkdir -p "$DATADIR"
    exec ${pkgs.rustfs}/bin/rustfs server \
      --address 127.0.0.1:9010 \
      --console-enable \
      --console-address 127.0.0.1:9011 \
      --access-key rustfsadmin \
      --secret-key rustfsadmin \
      "$DATADIR"
  '';

  opensearchDashboardsPrefix = "/opt/homebrew/opt/opensearch-dashboards";
  opensearchDashboardsDataDir = "/Users/${username}/.local/share/opensearch-dashboards";
  opensearchDashboardsStart = pkgs.writeShellScript "opensearch-dashboards-start" ''
    set -eu
    DATADIR=${opensearchDashboardsDataDir}
    CONFDIR="$DATADIR/config"
    mkdir -p "$CONFDIR" "$DATADIR/data" "$DATADIR/logs"

    # Always overwrite so dev config can't drift
    cat > "$CONFDIR/opensearch_dashboards.yml" <<EOF
    server.port: 5601
    server.host: "127.0.0.1"
    opensearch.hosts: ["http://127.0.0.1:9200"]
    opensearch.ssl.verificationMode: none
    path.data: $DATADIR/data
    EOF

    # Dashboards bundles the security plugin; our opensearch runs with security
    # disabled, so dashboards refuses to start until the plugin is removed.
    PLUGIN_DIR=${opensearchDashboardsPrefix}/libexec/plugins/securityDashboards
    PLUGIN_BIN=${opensearchDashboardsPrefix}/libexec/bin/opensearch-dashboards-plugin
    if [ -d "$PLUGIN_DIR" ] && [ -x "$PLUGIN_BIN" ]; then
      "$PLUGIN_BIN" remove securityDashboards || true
    fi

    # Wait for opensearch to come up before launching
    for _ in $(seq 1 60); do
      if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:9200 >/dev/null; then
        break
      fi
      sleep 2
    done

    exec ${opensearchDashboardsPrefix}/bin/opensearch-dashboards \
      --config "$CONFDIR/opensearch_dashboards.yml"
  '';

  opensearchDataDir = "/Users/${username}/.local/share/opensearch";
  opensearchStart = pkgs.writeShellScript "opensearch-start" ''
    set -eu
    DATADIR=${opensearchDataDir}
    CONFDIR="$DATADIR/config"
    mkdir -p "$DATADIR/data" "$DATADIR/logs"

    # First-run: copy stock config tree so log4j2.properties etc exist
    if [ ! -d "$CONFDIR" ]; then
      cp -r ${pkgs.opensearch}/config "$CONFDIR"
      chmod -R u+w "$CONFDIR"
    fi

    # Always overwrite opensearch.yml so dev config can't drift
    cat > "$CONFDIR/opensearch.yml" <<EOF
    cluster.name: dev
    node.name: dev-node
    network.host: 127.0.0.1
    http.port: 9200
    discovery.type: single-node
    path.data: $DATADIR/data
    path.logs: $DATADIR/logs
    plugins.security.disabled: true
    EOF

    # The opensearch native wrapper chdir's to OPENSEARCH_HOME (read-only nix
    # store) before launching the JVM, so the stock jvm.options' relative
    # paths (logs/gc.log, data, logs/hs_err_pid*) fail. Regenerate from stock
    # on every start with absolute paths under $DATADIR.
    sed \
      -e "s|HeapDumpPath=data|HeapDumpPath=$DATADIR/data|" \
      -e "s|ErrorFile=logs/|ErrorFile=$DATADIR/logs/|" \
      -e "s|file=logs/gc.log|file=$DATADIR/logs/gc.log|" \
      -e "s|-Xloggc:logs/gc.log|-Xloggc:$DATADIR/logs/gc.log|" \
      ${pkgs.opensearch}/config/jvm.options > "$CONFDIR/jvm.options"

    export OPENSEARCH_PATH_CONF="$CONFDIR"
    export OPENSEARCH_JAVA_OPTS="-Xms512m -Xmx1g"
    exec ${pkgs.opensearch}/bin/opensearch
  '';

in
{
  services.dnsmasq = {
    enable = true;
    addresses = {
      test = "127.0.0.1";
    };
  };

  environment.etc = {
    "resolver/test".text = ''
      nameserver 127.0.0.1
    '';

    "caddy/Caddyfile".text = ''
      {
        local_certs
      }

      import /Users/${username}/.config/caddy/sites/*.caddy
    '';

    # Rotate caddy logs so the daemon can't get wedged into EX_CONFIG / penalty
    # box when /var/log/caddy.err.log grows huge and SIGKILL leaves it in a state
    # launchd can't open.
    "newsyslog.d/caddy.conf".text = ''
      # logfilename                 [owner:group]  mode count size when  flags
      /var/log/caddy.err.log        root:wheel     644  5     10240 *    GN
      /var/log/caddy.out.log        root:wheel     644  5     10240 *    GN
    '';

  };

  launchd = {
    daemons.caddy = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.caddy}/bin/caddy"
          "run"
          "--config"
          "/etc/caddy/Caddyfile"
          "--adapter"
          "caddyfile"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        EnvironmentVariables = {
          HOME = "/var/root";
          XDG_CONFIG_HOME = "/var/root/.config";
          XDG_DATA_HOME = "/var/root/.local/share";
        };
        StandardOutPath = "/var/log/caddy.out.log";
        StandardErrorPath = "/var/log/caddy.err.log";
      };
    };

    user.agents = {
      mailpit = {
        serviceConfig = {
          ProgramArguments = [ "${pkgs.mailpit}/bin/mailpit" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/mailpit.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/mailpit.err.log";
        };
      };

      mysql = {
        serviceConfig = {
          ProgramArguments = [ "${mysqlStart}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/mysql.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/mysql.err.log";
        };
      };

      redis = {
        serviceConfig = {
          ProgramArguments = [ "${redisStart}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/redis.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/redis.err.log";
        };
      };

      postgres = {
        serviceConfig = {
          ProgramArguments = [ "${postgresStart}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/postgres.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/postgres.err.log";
        };
      };

      minio = {
        serviceConfig = {
          ProgramArguments = [ "${minioStart}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/minio.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/minio.err.log";
        };
      };

      rustfs = {
        serviceConfig = {
          ProgramArguments = [ "${rustfsStart}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/rustfs.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/rustfs.err.log";
        };
      };

      opensearch = lib.mkIf (hostname == "work") {
        serviceConfig = {
          ProgramArguments = [ "${opensearchStart}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/opensearch.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/opensearch.err.log";
        };
      };

      opensearch-dashboards = lib.mkIf (hostname == "work") {
        serviceConfig = {
          ProgramArguments = [ "${opensearchDashboardsStart}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${username}/Library/Logs/opensearch-dashboards.out.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/opensearch-dashboards.err.log";
        };
      };
    };
  };
}
