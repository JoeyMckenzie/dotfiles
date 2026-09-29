{ pkgs, ... }:

{
  programs.nixvim = {
    # Org files live in ~/org. Default mappings sit under <leader>o (<leader>oa agenda, <leader>oc
    # capture).
    plugins.orgmode = {
      enable = true;
      settings = {
        org_agenda_files = "~/org/**/*";
        org_default_notes_file = "~/org/refile.org";

        # NEXT is what I'm actually doing next; WAITING is blocked on someone.
        org_todo_keywords = [
          "TODO"
          "NEXT"
          "WAITING"
          "|"
          "DONE"
          "CANCELLED"
        ];

        org_capture_templates = {
          t = {
            description = "Task";
            template = "* TODO %?\n  %u";
          };
          w = {
            description = "Work task";
            template = "* TODO %?\n  %u";
            target = "~/org/work.org";
          };
          n = {
            description = "Note";
            template = "* %?\n  %U";
          };
        };

        # <leader>oa d: today, then next actions, then what's blocked.
        org_agenda_custom_commands.d = {
          description = "Dashboard";
          types = [
            {
              type = "agenda";
              org_agenda_span = "day";
            }
            {
              type = "tags_todo";
              match = "/NEXT";
              org_agenda_overriding_header = "Next actions";
            }
            {
              type = "tags_todo";
              match = "/WAITING";
              org_agenda_overriding_header = "Waiting on";
            }
          ];
        };
      };
    };

    # orgmode compiles its tree-sitter parser into stdpath("data") on first
    # launch unless one is already on the runtimepath. Ship the nixpkgs
    # grammar instead. It must be named parser/org.so (nixpkgs calls it
    # org_nvim); orgmode bundles its own queries, so the parser is enough.
    extraPlugins = [
      (pkgs.runCommand "orgmode-parser" { } ''
        mkdir -p $out/parser
        ln -s ${pkgs.tree-sitter-grammars.tree-sitter-org-nvim}/parser $out/parser/org.so
      '')
      pkgs.vimPlugins.org-roam-nvim
    ];

    # org-roam has no nixvim module. Linked notes and dailies live under the
    # agenda glob, so TODOs written in notes still show up in the agenda.
    # Default mappings sit under <leader>n (<leader>nf find, <leader>ni
    # insert link, <leader>nl backlinks, <leader>ndN today's daily).
    extraConfigLua = ''
      require("org-roam").setup({
        directory = "~/org/notes",
      })
    '';

    # orgmode ships a blink source for TODO keywords, tags, and properties.
    plugins.blink-cmp.settings.sources = {
      per_filetype.org = [
        "orgmode"
        "path"
        "snippets"
        "buffer"
      ];
      providers.orgmode = {
        name = "Orgmode";
        module = "orgmode.org.autocompletion.blink";
        fallbacks = [ "buffer" ];
      };
    };
  };
}
