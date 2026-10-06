#!/usr/bin/env bash
set -euo pipefail

json_get() {
    local path="${1#.}"
    PAYLOAD="$PAYLOAD" KEY="$path" perl -MJSON::PP -e '
        my $d = JSON::PP->new->utf8->decode($ENV{PAYLOAD});
        my @k = split /\./, $ENV{KEY};
        my $v = $d;
        for (@k) { $v = ref($v) eq "HASH" ? $v->{$_} : undef; last unless defined $v; }
        print defined($v) ? $v : "";
    '
}

json_edits() {
    PAYLOAD="$PAYLOAD" WHICH="$1" perl -MJSON::PP -e '
        my $d = JSON::PP->new->utf8->decode($ENV{PAYLOAD});
        my $e = $d->{tool_input}{edits};
        exit 0 unless ref($e) eq "ARRAY";
        print join("\n", map { defined($_->{$ENV{WHICH}}) ? $_->{$ENV{WHICH}} : "" } @$e);
    '
}

PAYLOAD=$(cat)
tool_name=$(json_get '.tool_name')
case "$tool_name" in
    Write|Edit|MultiEdit) ;;
    *) exit 0 ;;
esac

file_path=$(json_get '.tool_input.file_path')
[[ -z "$file_path" ]] && exit 0

case "$file_path" in
    */config/*.php) exit 0 ;;
    */public/index.php) exit 0 ;;
    */tsconfig.json|*/tsconfig.*.json) exit 0 ;;
    */resources/js/components/ui/*) exit 0 ;;
    */resources/views/mail/*) exit 0 ;;
esac

filename="${file_path##*/}"

case "$filename" in
    *.blade.php) style="blade" ;;
    *)
        ext="${filename##*.}"
        [[ "$ext" == "$filename" ]] && exit 0
        ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
        case "$ext" in
            go|swift|js|jsx|ts|tsx|mjs|cjs|java|kt|rs|c|h|cc|cpp|hpp|cs|scala|m|mm) style="cfamily" ;;
            json|jsonc|json5) style="cfamily" ;;
            sh|bash|py|rb) style="hash" ;;
            yaml|yml) style="hash" ;;
            php) style="php" ;;
            *) exit 0 ;;
        esac
        ;;
esac

is_allowed_line() {
    local s="${1%"${1##*[![:space:]]}"}"
    case "$s" in
        '//') return 0 ;;
        '#!'*) return 0 ;;
        '//go:'*) return 0 ;;
        '// +build'*) return 0 ;;
        '// Code generated'*) return 0 ;;
        '//nolint'*) return 0 ;;
        '// @ts-'*|'//@ts-'*) return 0 ;;
        '/// <'*) return 0 ;;
        '// eslint-'*|'//eslint-'*|'/* eslint-'*|'/*eslint-'*) return 0 ;;
        '// prettier-ignore'*|'//prettier-ignore'*|'/* prettier-ignore'*) return 0 ;;
        '# shellcheck'*|'#shellcheck'*) return 0 ;;
        '// @phpstan-'*|'//@phpstan-'*) return 0 ;;
        '// @vitest-environment'*|'//@vitest-environment'*) return 0 ;;
        '/* @chisel-'*|'/*@chisel-'*|'/* @end-chisel-'*|'/*@end-chisel-'*) return 0 ;;
        '// Credit:'*|'//Credit:'*) return 0 ;;
    esac
    return 1
}

is_doc_typing_line() {
    local s="$1"
    s="${s%\*/}"
    s="${s#/\*\*}"
    s="${s#/\*}"
    s="${s#\*}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    [[ -z "$s" ]] && return 0
    case "$s" in
        @param*|@return*|@var*|@template*|@implements*|@extends*|@phpstan-*|@psalm-*|@method*|@property*|@mixin*|@inheritDoc*|@inheritdoc*) return 0 ;;
        @use*|@see*|@throws*|@deprecated*|@link*) return 0 ;;
        @type*|@satisfies*|@callback*) return 0 ;;
    esac
    return 1
}

emit_comments() {
    local text="$1" style="$2"
    local in_block=0 i n line stripped norm
    local -a lines=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        lines+=("$line")
    done <<<"$text"
    n=${#lines[@]}
    for (( i=0; i<n; i++ )); do
        line="${lines[$i]}"
        stripped="${line#"${line%%[![:space:]]*}"}"
        norm="${stripped%"${stripped##*[![:space:]]}"}"
        if [[ "$style" == "blade" ]]; then
            if (( in_block )); then
                [[ "$line" == *'--}}'* || "$line" == *'-->'* ]] && in_block=0
                printf 'B\t%s\n' "$norm"
                continue
            fi
            if [[ "$stripped" == '{{--'* || "$stripped" == '<!--'* ]]; then
                [[ "$line" != *'--}}'* && "$line" != *'-->'* ]] && in_block=1
                printf 'B\t%s\n' "$norm"
                continue
            fi
            continue
        fi
        if [[ "$style" == "cfamily" || "$style" == "php" ]]; then
            if (( in_block )); then
                [[ "$line" == *'*/'* ]] && in_block=0
                is_doc_typing_line "$stripped" && continue
                printf 'B\t%s\n' "$norm"
                continue
            fi
            if [[ "$stripped" == '/*'* ]]; then
                [[ "$line" != *'*/'* ]] && in_block=1
                is_allowed_line "$stripped" && continue
                is_doc_typing_line "$stripped" && continue
                printf 'B\t%s\n' "$norm"
                continue
            fi
            if [[ "$stripped" == '//'* ]]; then
                is_allowed_line "$stripped" && continue
                printf 'L\t%s\n' "$norm"
                continue
            fi
        fi
        if [[ "$style" == "hash" || "$style" == "php" ]]; then
            if [[ "$stripped" == '#'* ]]; then
                if [[ "$style" == "php" && "$stripped" == '#['* ]]; then
                    continue
                fi
                is_allowed_line "$stripped" && continue
                printf 'L\t%s\n' "$norm"
                continue
            fi
        fi
    done
}

case "$tool_name" in
    Write)
        new_text=$(json_get '.tool_input.content')
        if [[ -f "$file_path" ]]; then old_text=$(cat "$file_path"); else old_text=""; fi
        ;;
    Edit)
        old_text=$(json_get '.tool_input.old_string')
        new_text=$(json_get '.tool_input.new_string')
        ;;
    MultiEdit)
        old_text=$(json_edits old_string)
        new_text=$(json_edits new_string)
        ;;
esac

old_emit=$(emit_comments "$old_text" "$style")
new_emit=$(emit_comments "$new_text" "$style")

added=$(LC_ALL=C comm -13 <(printf '%s\n' "$old_emit" | LC_ALL=C sort) <(printf '%s\n' "$new_emit" | LC_ALL=C sort) || true)
added_lines=$(printf '%s\n' "$added" | grep -c $'^L\t' || true)
added_blocks=$(printf '%s\n' "$added" | grep -c $'^B\t' || true)
added_total=$((added_lines + added_blocks))

if (( added_total <= 0 )); then
    exit 0
fi

cat >&2 <<MSG
COMMENT BLOCKED -- ${tool_name} on ${file_path}. You may not write prose comments. Load-bearing comments the code cannot compile, lint, or run without are already allow-listed and pass silently -- as are PHP typing docblocks and the bare \`//\` that separates an empty constructor's braces.

DEFAULT: delete the comment and keep working.

IF THE "WHY" IS WORTH KEEPING, it goes in the nearest CONTEXT.md, or the commit body. A constraint the next reader must not break, or why an approach beat the obvious one, is a short \`## <topic>\` section in the CONTEXT.md of the nearest sensible folder -- that folder's decision log, not the root glossary.

A change's story -- what you just fixed, what you tried, a note to your future self -- is not a decision. That belongs in the commit body or the PR, never in the code and never in CONTEXT.md.

ONLY if a comment is genuinely required and not yet allow-listed: do NOT write it and do NOT defer it. STOP all work now, tell the user the exact comment and where it goes, and wait for them to add it by hand (or approve a carve-out in the global hook, home/hooks/anti-comment-vomit.sh in the nix-darwin config). Treat that as blocking work that must actually get done -- not a suggestion.

This is rare. Never accumulate comment suggestions or end a response with "you should add these comments" -- if you reach for this more than almost never, you are wrong: delete and move on.
MSG
exit 2
