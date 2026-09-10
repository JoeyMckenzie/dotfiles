{ pkgs, inputs, ... }:

let
  matt = "${inputs.mattpocock-skills}/skills";
  ld = "${inputs.launchdarkly-skills}/skills";

  # Upstream names this one just "onboarding", too generic for a global skills
  # dir. Rename the dir and keep the frontmatter name in sync so both agree.
  ldOnboarding = pkgs.runCommand "launchdarkly-onboarding" { } ''
    cp -r ${ld}/onboarding $out
    chmod u+w $out $out/SKILL.md
    substituteInPlace $out/SKILL.md --replace-fail "name: onboarding" "name: launchdarkly-onboarding"
  '';

  # Upstream still passes ffmpeg's `-vsync`, removed in ffmpeg 9. Swap in the
  # modern `-fps_mode` spelling so frame extraction works again.
  watchSkill = pkgs.runCommand "watch-skill" { } ''
    cp -r ${inputs.claude-video-skills}/skills/watch $out
    chmod u+w $out $out/scripts $out/scripts/frames.py
    substituteInPlace $out/scripts/frames.py \
      --replace-fail '"-vsync", "vfr",' '"-fps_mode", "vfr",'
  '';

  # Skills vendored from upstream repos, pinned by flake.lock. Each entry picks
  # one skill dir out of its source repo; bump one with:
  #   nix flake update mattpocock-skills
  upstream = pkgs.linkFarm "upstream-skills" {
    code-review = "${matt}/engineering/code-review";
    codebase-design = "${matt}/engineering/codebase-design";
    diagnosing-bugs = "${matt}/engineering/diagnosing-bugs";
    domain-modeling = "${matt}/engineering/domain-modeling";
    grill-with-docs = "${matt}/engineering/grill-with-docs";
    prototype = "${matt}/engineering/prototype";
    tdd = "${matt}/engineering/tdd";
    triage = "${matt}/engineering/triage";
    grill-me = "${matt}/productivity/grill-me";
    grilling = "${matt}/productivity/grilling";
    handoff = "${matt}/productivity/handoff";
    wait-what = "${matt}/productivity/wait-what";
    writing-for-agents = "${matt}/productivity/writing-for-agents";

    # Other skills I like to keep around
    caveman = "${inputs.caveman-skills}/skills/caveman";
    diagram-design = "${inputs.diagram-design-skills}/skills/diagram-design";
    find-skills = "${inputs.vercel-skills}/skills/find-skills";
    gh-stack = "${inputs.gh-stack-skills}/skills/gh-stack";
    ponytail = "${inputs.ponytail-skills}/skills/ponytail";
    watch = watchSkill;

    flag-and-release-change = "${ld}/feature-flags/flag-and-release-change";
    flag-release = "${ld}/feature-flags/flag-release";
    launchdarkly-flag-cleanup = "${ld}/feature-flags/launchdarkly-flag-cleanup";
    launchdarkly-flag-command = "${ld}/feature-flags/launchdarkly-flag-command";
    launchdarkly-flag-create = "${ld}/feature-flags/launchdarkly-flag-create";
    launchdarkly-flag-discovery = "${ld}/feature-flags/launchdarkly-flag-discovery";
    launchdarkly-flag-drift = "${ld}/feature-flags/launchdarkly-flag-drift";
    launchdarkly-flag-qualitative-feedback-setup = "${ld}/feature-flags/launchdarkly-flag-qualitative-feedback-setup";
    launchdarkly-flag-targeting = "${ld}/feature-flags/launchdarkly-flag-targeting";
    launchdarkly-guarded-rollout = "${ld}/feature-flags/launchdarkly-guarded-rollout";
    should-flag-change = "${ld}/feature-flags/should-flag-change";
    launchdarkly-metric-choose = "${ld}/metrics/launchdarkly-metric-choose";
    launchdarkly-metric-create = "${ld}/metrics/launchdarkly-metric-create";
    launchdarkly-metric-instrument = "${ld}/metrics/launchdarkly-metric-instrument";
    launchdarkly-experiment-setup = "${ld}/experiments/launchdarkly-experiment-setup";
    launchdarkly-onboarding = ldOnboarding;
  };

  skills = pkgs.symlinkJoin {
    name = "agent-skills";
    paths = [
      upstream
      ./skills/_local
      "${inputs.obsidian-skills}/skills"
    ];
  };
in
{
  home.file = {
    ".claude/skills" = {
      source = skills;
      recursive = true;
    };

    ".codex/skills" = {
      source = skills;
      recursive = true;
    };

    ".claude/CLAUDE.md".source = ./agent-instructions.md;
    ".codex/AGENTS.md".source = ./agent-instructions.md;

    ".claude/agents" = {
      source = ./agents;
      recursive = true;
    };
  };

  # pi resolves its agent dir from PI_CODING_AGENT_DIR (see pi.nix).
  xdg.configFile."pi/skills" = {
    source = skills;
    recursive = true;
  };
}
