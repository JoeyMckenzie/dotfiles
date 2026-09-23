{ pkgs, inputs, ... }:

{
  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
    package = inputs.worktrunk.packages.${pkgs.system}.default;

    claudeCodeIntegration = {
      enable = true;
      switchCreateSkill = false;
    };

    settings = {
      worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}";
      post-start.nix-bootstrap = ''
        case "{{ worktree_path }}" in
          */givebutter-monorepo/*)
            seeder="$(git -C "{{ worktree_path }}" rev-parse --git-common-dir)/../main/nix/bin/seed-worktree"
            if [ -x "$seeder" ]; then
              "$seeder" "{{ worktree_path }}" --no-warm
            else
              echo "⚠ scaffold seeder not found at $seeder" >&2
            fi
            ;;
        esac
      '';

      commit.generation = {
        command = "CLAUDECODE= MAX_THINKING_TOKENS=0 claude -p --model=haiku --tools='' --disable-slash-commands --setting-sources='' --system-prompt=''";

        template = ''
          Write a commit message for the staged changes below.

          <format>
          - Commit message MUST have a co-author trailer of "Co-Authored-By: Claude Haiku 4.6 <noreply@anthropic.com>"
          - Subject line MUST use a conventional commit prefix: feat, fix, refactor, chore, docs, test, style, perf, ci, build
          - Subject line format: `type(scope): description` or `type: description`
          - Subject line under 50 chars, lowercase, no period
          - Add a blank line then a body paragraph describing what changed and why
          - Body lines wrap at 72 chars
          - Output only the commit message, no quotes or code blocks
          </format>

          <style>
          - Imperative mood: "add feature" not "added feature"
          - Scope is optional but encouraged when the change is localized (e.g. auth, api, ui)
          - The body should explain context a reviewer would find useful, not just restate the diff
          </style>

          <diffstat>
          {{ git_diff_stat }}
          </diffstat>

          <diff>
          {{ git_diff }}
          </diff>

          <context>
          Branch: {{ branch }}
          {% if recent_commits %}<recent_commits>
          {% for commit in recent_commits %}- {{ commit }}
          {% endfor %}</recent_commits>{% endif %}
          </context>
        '';

        squash-template = ''
          Combine these commits into a single commit message.

          <format>
          - Subject line MUST use a conventional commit prefix: feat, fix, refactor, chore, docs, test, style, perf, ci, build
          - Subject line format: `type(scope): description` or `type: description`
          - Subject line under 50 chars, lowercase, no period
          - Add a blank line then a body paragraph summarizing the overall change and why it was made
          - Body lines wrap at 72 chars
          - Output only the commit message, no quotes or code blocks
          </format>

          <commits branch="{{ branch }}" target="{{ target_branch }}">
          {% for commit in commits %}- {{ commit }}
          {% endfor %}</commits>

          <diffstat>
          {{ git_diff_stat }}
          </diffstat>

          <diff>
          {{ git_diff }}
          </diff>
        '';
      };

      list.summary = true;
    };
  };
}
