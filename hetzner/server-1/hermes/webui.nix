# Hermes WebUI — the community browser front-end (nesquena/hermes-webui) for
# the agent that ALREADY runs on this host, next to the workbench dashboard.
#
# Why this one and not the open-webui container (llm-ui.nix): the WebUI runs
# the Hermes agent IN-PROCESS and reads HERMES_HOME directly, so its chats
# write real Hermes sessions — resumable from the CLI/Telegram/dashboard and
# visible in the session bridge. A frontend over the stateless
# /v1/chat/completions API (open-webui) keeps its own transcript DB and never
# creates Hermes-side history.
#
# Exposure: loopback-only on purpose. Reach it through an SSH tunnel
# (`ssh -N -L 8787:127.0.0.1:8787 hetzner-server-1…`) until a caddy vhost is
# decided on — the password (below) is defense in depth for that day, not an
# invitation to expose the port. The UI executes the agent (shell tools), so
# treat any exposure decision like the dashboard's.
{
  config,
  hermesPorts,
  ...
}:

{
  services.hermes-webui = {
    enable = true;
    port = hermesPorts.webui;

    # Run as the agent's service account (per upstream README: "run the
    # service as a user that can already read that state"): the in-process
    # agent and the file browser read HERMES_HOME (state.db sessions,
    # config.yaml, .env, workspace) — a dedicated hermes-webui user could read
    # none of it without ACL surgery. Literals, not config.users.*.name:
    # reading the user back here cycles with this module's own
    # users.users/groups mkIf (cfg.user == default) definitions.
    user = "hermes";
    group = "hermes";

    hermesHome = "/var/lib/hermes/.hermes";
    # Same place a plain install would put it ($HERMES_HOME/webui), so webui
    # state sits with the rest of the agent's state.
    stateDir = "/var/lib/hermes/.hermes/webui";

    # The SAME package the gateway service runs: the upstream module derives
    # HERMES_WEBUI_PYTHON from its passthru.hermesVenv (the agent venv carries
    # the deps the in-process agent imports) and bootstrap.py then locates the
    # agent source through that interpreter. Reading the option (instead of
    # re-pointing at the flake input) keeps the two in lockstep by
    # construction — one bump, both services move.
    agent.package = config.services.hermes-agent.package;

    extraEnvironment = {
      # Each warm agent instance pins its whole transcript in RAM (upstream
      # default 25); sessions here get long, so cap the in-memory LRU on this
      # small box. Eviction only drops clean, persisted sessions and lazily
      # reloads them from disk.
      HERMES_WEBUI_AGENT_CACHE_MAX = "8";
    };

    # Password auth (sops-rendered; the WebUI ships password auth off by
    # default). Passkeys/OIDC can be layered on later from the UI.
    environmentFiles = [ config.sops.templates."webui-env".path ];
  };
}
