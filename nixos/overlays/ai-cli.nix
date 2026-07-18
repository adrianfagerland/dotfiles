final: prev:
let
  inherit (final) lib;

  codexTarget = "x86_64-unknown-linux-musl";

  codex-bin = final.stdenvNoCC.mkDerivation rec {
    pname = "codex";
    version = "0.144.6";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-linux-x64.tgz";
      hash = "sha256-tnUusujBDm/MlqxcHIrYNCzbmnRQT7hGhq3fCBp9KGg=";
    };

    nativeBuildInputs = [
      final.makeWrapper
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/codex"
      cp -R vendor/${codexTarget}/. "$out/share/codex/"

      makeWrapper "$out/share/codex/bin/codex" "$out/bin/codex" \
        --prefix PATH : "$out/share/codex/codex-path" \
        --set CODEX_MANAGED_BY_NPM 1 \
        --set CODEX_MANAGED_PACKAGE_ROOT "$out/share/codex"

      runHook postInstall
    '';

    meta = {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

  claude-code-bin = final.stdenvNoCC.mkDerivation rec {
    pname = "claude-code";
    version = "2.1.214";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-${version}.tgz";
      hash = "sha256-6i9ELLvrkN3t4MzEjKV4XZMJWbI3mziTKY3MSGQc06k=";
    };

    nativeBuildInputs = [
      final.makeWrapper
    ];

    installPhase = ''
      runHook preInstall

      install -Dm755 claude "$out/libexec/claude-code/claude"
      install -Dm644 package.json "$out/libexec/claude-code/package.json"
      makeWrapper "$out/libexec/claude-code/claude" "$out/bin/claude" \
        --set DISABLE_AUTOUPDATER 1 \
        --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        --set USE_BUILTIN_RIPGREP 0 \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ final.alsa-lib ]} \
        --prefix PATH : ${lib.makeBinPath [
          final.procps
          final.ripgrep
          final.bubblewrap
          final.socat
        ]}

      runHook postInstall
    '';

    meta = {
      description = "Agentic coding tool that lives in your terminal";
      homepage = "https://github.com/anthropics/claude-code";
      downloadPage = "https://claude.com/product/claude-code";
      license = lib.licenses.unfree;
      mainProgram = "claude";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };
in
{
  codex = codex-bin;
  claude-code = claude-code-bin;
}
