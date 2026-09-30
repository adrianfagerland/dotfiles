{ config, lib, pkgs, ... }:

# Claude models for Codex CLI/Desktop. Codex only speaks the OpenAI Responses
# API, which Anthropic does not serve, so a loopback LiteLLM proxy translates
# Responses requests into Messages API calls. `codex-provider claude|openai`
# flips ~/.codex/config.toml between the two providers and starts or stops the
# proxy to match.
let
  port = 4100;
  baseUrl = "http://127.0.0.1:${toString port}/v1";
  apiKeyFile = "${config.xdg.configHome}/litellm/anthropic.env";
  proxyKeyFile = "${config.xdg.configHome}/litellm/proxy.env";
  catalogPath = "${config.xdg.configHome}/codex/claude-models.json";
  enabledMarker = "${config.xdg.stateHome}/codex-provider/claude-enabled";

  efforts = {
    low = "Fast responses with lighter reasoning";
    medium = "Balances speed and reasoning depth for everyday tasks";
    high = "Greater reasoning depth for complex problems";
    xhigh = "Extra high reasoning depth for long agentic coding work";
    max = "Maximum reasoning depth for the hardest problems";
  };

  # LiteLLM's bundled model map predates these releases. Without capability
  # metadata it silently drops thinking/effort and caps output at 4096 tokens.
  claude5ModelInfo = {
    litellm_provider = "anthropic";
    mode = "chat";
    max_input_tokens = 1000000;
    max_output_tokens = 128000;
    max_tokens = 128000;
    supports_adaptive_thinking = true;
    supports_reasoning = true;
    supports_output_config = true;
    supports_xhigh_reasoning_effort = true;
    supports_max_reasoning_effort = true;
    supports_prompt_caching = true;
    supports_function_calling = true;
    supports_tool_choice = true;
    supports_vision = true;
    supports_pdf_input = true;
    supports_assistant_prefill = false;
    supports_sampling_params = false;
  };

  models = [
    {
      slug = "claude-opus-5-5";
      name = "Claude Opus 5.5";
      description = "Anthropic's newest Opus for coding and agentic work.";
      modelInfo = claude5ModelInfo // {
        input_cost_per_token = 4.0e-6;
        output_cost_per_token = 2.0e-5;
      };
    }
    {
      slug = "claude-fable-5-1";
      name = "Claude Fable 5.1";
      description = "Anthropic's most capable model; slower and pricier than Opus.";
      modelInfo = claude5ModelInfo // {
        input_cost_per_token = 1.0e-5;
        output_cost_per_token = 5.0e-5;
      };
    }
    { slug = "claude-opus-5"; name = "Claude Opus 5"; description = "Previous Opus generation."; }
    { slug = "claude-sonnet-5"; name = "Claude Sonnet 5"; description = "Faster, cheaper everyday coding model."; }
    {
      slug = "claude-haiku-4-5";
      name = "Claude Haiku 4.5";
      description = "Fastest and cheapest Claude model.";
      contextWindow = 200000;
      maxOutput = 64000;
      levels = [ "low" "medium" "high" ];
    }
  ];

  catalogEntry = priority: m: let
    contextWindow = m.contextWindow or 1000000;
  in {
    inherit (m) slug description;
    display_name = m.name;
    default_reasoning_level = "high";
    supported_reasoning_levels = map (effort: {
      inherit effort;
      description = efforts.${effort};
    }) (m.levels or [ "low" "medium" "high" "xhigh" "max" ]);
    shell_type = "unified_exec";
    visibility = "list";
    supported_in_api = true;
    inherit priority;
    additional_speed_tiers = [ ];
    service_tiers = [ ];
    availability_nux = null;
    upgrade = null;
    # Codex's model-neutral prompt (what it sends for unknown models), captured
    # from Codex 0.155; the catalog's GPT entries carry a GPT-specific persona.
    base_instructions = builtins.readFile ./codex-claude-instructions.md;
    model_messages = null;
    include_skills_usage_instructions = true;
    include_plugin_usage_instructions = true;
    include_apps_usage_instructions = true;
    default_reasoning_summary = "none";
    support_verbosity = false;
    default_verbosity = null;
    apply_patch_tool_type = "freeform";
    web_search_tool_type = "text";
    truncation_policy = {
      mode = "tokens";
      limit = 10000;
    };
    supports_image_detail_original = false;
    context_window = contextWindow;
    max_context_window = contextWindow;
    effective_context_window_percent = 95;
    experimental_supported_tools = [ ];
    input_modalities = [ "text" "image" ];
    supports_search_tool = false;
    supports_experimental_context = false;
    use_responses_lite = false;
    node_repl_auto_review_required = false;
    node_repl_disabled = false;
  };

  catalog = {
    models = lib.imap1 catalogEntry models;
  };

  # JSON is valid YAML, which is what LiteLLM expects for --config.
  litellmConfig = pkgs.writeText "codex-claude-litellm.yaml" (builtins.toJSON {
    model_list = map (m: {
      model_name = m.slug;
      litellm_params = {
        model = "anthropic/${m.slug}";
        api_key = "os.environ/ANTHROPIC_API_KEY";
        # Codex never sends an output limit and LiteLLM's default is 4096.
        max_tokens = m.maxOutput or 128000;
        # Anthropic only caches explicitly marked prefixes; without these every
        # agent turn would resend the whole conversation at full input price.
        cache_control_injection_points = [
          { location = "message"; role = "system"; }
          { location = "message"; index = -1; }
        ];
      };
    } // lib.optionalAttrs (m ? modelInfo) { model_info = m.modelInfo; }) models;
    litellm_settings.drop_params = true;
    # Loopback is still reachable from browser pages, so require a bearer token.
    general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";
  });

  ensureProxyKey = pkgs.writeShellScript "codex-claude-proxy-key" ''
    set -eu
    key_file=${lib.escapeShellArg proxyKeyFile}
    if [ ! -s "$key_file" ]; then
      umask 077
      mkdir -p "$(dirname "$key_file")"
      printf 'LITELLM_MASTER_KEY=sk-local-%s\n' \
        "$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -c1-48)" \
        > "$key_file"
    fi
  '';

  codexProvider = pkgs.writeShellApplication {
    name = "codex-provider";
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.tomlkit ])) pkgs.systemd ];
    text = ''
      exec python3 ${./scripts/codex-provider.py} \
        --catalog ${lib.escapeShellArg catalogPath} \
        --base-url ${lib.escapeShellArg baseUrl} \
        --token-file ${lib.escapeShellArg proxyKeyFile} \
        --marker ${lib.escapeShellArg enabledMarker} \
        "$@"
    '';
  };
in
{
  home.packages = [ codexProvider ];

  xdg.configFile."codex/claude-models.json".text = builtins.toJSON catalog;

  # Only runs while Codex is switched to Claude; `codex-provider` owns the marker.
  systemd.user.services.codex-claude-proxy = {
    Unit = {
      Description = "LiteLLM proxy serving Claude to Codex over the Responses API";
      ConditionPathExists = [ apiKeyFile enabledMarker ];
    };
    Service = {
      ExecStartPre = "${ensureProxyKey}";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.litellm}/bin/litellm"
        "--config ${litellmConfig}"
        "--host 127.0.0.1"
        "--port ${toString port}"
        "--telemetry False"
      ];
      EnvironmentFile = [ apiKeyFile "-${proxyKeyFile}" ];
      Environment = [
        # Use the bundled model map instead of fetching one from GitHub at startup.
        "LITELLM_LOCAL_MODEL_COST_MAP=True"
        "LITELLM_LOG=WARNING"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
      NoNewPrivileges = true;
      MemoryHigh = "768M";
      MemoryMax = "1G";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
