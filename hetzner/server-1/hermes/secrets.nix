{
  config,
  ...
}:

{
  # individual keys from inputs.MyServersSecrets secrets/hetzner/server-1.yaml
  sops.secrets = {
    OPENROUTER_API_KEY = { };
    OPENCODE_GO_API_KEY = { };
    API_SERVER_KEY = { };
    EXA_API_KEY = { };
    TELEGRAM_BOT_TOKEN_AI = { };
    GITHUB_TOKEN_AI = { };
    CONTEXT7_API_KEY = { };
    GRAFANA_SERVICE_ACCOUNT_TOKEN = { };
    WEBUI_PASSWORD = { };
  };

  # rendered into the env file the gateway reads at startup; the raw secrets
  # stay root-only, only the rendered file is owned by hermes
  sops.templates."hermes-env" = {
    content = ''
      OPENROUTER_API_KEY=${config.sops.placeholder.OPENROUTER_API_KEY}
      OPENCODE_GO_API_KEY=${config.sops.placeholder.OPENCODE_GO_API_KEY}
      API_SERVER_KEY=${config.sops.placeholder.API_SERVER_KEY}
      EXA_API_KEY=${config.sops.placeholder.EXA_API_KEY}
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN_AI}
      GITHUB_TOKEN=${config.sops.placeholder.GITHUB_TOKEN_AI}
      TELEGRAM_ALLOWED_USERS=1228209533
      CONTEXT7_API_KEY=${config.sops.placeholder.CONTEXT7_API_KEY}
      GRAFANA_SERVICE_ACCOUNT_TOKEN=${config.sops.placeholder.GRAFANA_SERVICE_ACCOUNT_TOKEN}
    '';
    owner = config.users.users.hermes.name;
    group = config.users.groups.hermes.name;
    restartUnits = [
      "hermes-agent.service"
      "hermes-backend.service"
      # The WebUI runs the agent in-process against the same HERMES_HOME, so
      # provider-key changes restart it too (its warm agent instances cache
      # config; a restart is the only guarantee they re-read it).
      "hermes-webui.service"
    ];
  };

  sops.templates."webui-env" = {
    # HERMES_WEBUI_PASSWORD enables the WebUI's password auth (off by
    # default). The service binds 127.0.0.1 (webui.nix), so this gates SSH
    # tunnels today and is the first gate if a caddy vhost ever lands.
    # NOT a protected runtime key — the upstream module's ExecStartPre check
    # only rejects host/port/state/agent wiring in environmentFiles.
    content = ''
      HERMES_WEBUI_PASSWORD=${config.sops.placeholder.WEBUI_PASSWORD}
    '';
    owner = config.users.users.hermes.name;
    group = config.users.groups.hermes.name;
    restartUnits = [ "hermes-webui.service" ];
  };

  # gh CLI credentials for the AGENT's shell (gh comes from extraPackages).
  # Why a file and not the environment: hermes strips Tier-1 secrets —
  # GITHUB_TOKEN / GH_TOKEN — from every terminal and execute_code child, and
  # `terminal.env_passthrough` cannot re-allow them (provider/tool credentials
  # are blocked on purpose, GHSA-rhgp-j443-p4rf; docs: "Hermes-managed provider
  # credentials can never be re-allowed this way"). gh reads
  # ~/.config/gh/hosts.yml instead, and on the LOCAL terminal backend files are
  # simply accessible — the documented route for file credentials.
  # Shape: the bundled github skill's headless fallback (users map + flat
  # oauth_token + user). Verified on this host with
  # `env -u GITHUB_TOKEN -u GH_TOKEN gh auth status` / `gh api /user`. The
  # users map ALONE is rejected by gh ("the token ... is invalid"); the flat
  # `oauth_token:` line is what it actually uses.
  sops.templates."gh-hosts" = {
    content = ''
      github.com:
          users:
              Alper-Celiks-Agent:
                  oauth_token: ${config.sops.placeholder.GITHUB_TOKEN_AI}
          git_protocol: https
          oauth_token: ${config.sops.placeholder.GITHUB_TOKEN_AI}
          user: Alper-Celiks-Agent
    '';
    path = "/var/lib/hermes/.config/gh/hosts.yml";
    mode = "0600";
    owner = config.users.users.hermes.name;
    group = config.users.groups.hermes.name;
  };

  # Git HTTPS credentials for the AGENT's shell — a second, gh-independent
  # route to the same token: `git push` authenticates from this file through
  # git's `store` helper (wired up by the GIT_CONFIG_* variables in
  # `environment` in settings.nix) rather than through `gh auth git-credential`
  # from the hand-managed ~/.gitconfig, so HTTPS pushes keep working even if
  # gh is dropped again. Belongs to the same reasoning as the gh block above:
  # hermes strips Tier-1 secrets — GITHUB_TOKEN / GH_TOKEN — from every
  # terminal and execute_code child, and `terminal.env_passthrough` cannot
  # re-allow them (provider/tool credentials are blocked on purpose,
  # GHSA-rhgp-j443-p4rf). git's store helper reads $HOME/.git-credentials, and
  # on the LOCAL terminal backend files are simply accessible — the documented
  # route for file credentials.
  # Format: one `https://user:token@host` line per host, 0600, owner hermes.
  sops.templates."git-credentials" = {
    content = ''
      https://Alper-Celiks-Agent:${config.sops.placeholder.GITHUB_TOKEN_AI}@github.com
    '';
    path = "/var/lib/hermes/.git-credentials";
    mode = "0600";
    owner = config.users.users.hermes.name;
    group = config.users.groups.hermes.name;
  };
}
