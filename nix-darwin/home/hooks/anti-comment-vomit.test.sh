#!/usr/bin/env bash
set -uo pipefail

HOOK="${HOOK:-$(dirname "${BASH_SOURCE[0]}")/anti-comment-vomit.sh}"
R=/project
pass=0
fail=0

check() {
    local name="$1" want="$2" payload="$3"
    printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
    local got=$?
    if [[ "$got" == "$want" ]]; then
        printf 'ok   %-46s (exit %s)\n' "$name" "$got"
        pass=$((pass + 1))
    else
        printf 'FAIL %-46s want %s got %s\n' "$name" "$want" "$got"
        fail=$((fail + 1))
    fi
}

edit() {
    local name="$1" want="$2" fp="$3" old="$4" new="$5"
    check "$name" "$want" "$(OLD="$old" NEW="$new" FP="$fp" perl -MJSON::PP -e '
        print JSON::PP->new->utf8->encode({
            tool_name  => "Edit",
            tool_input => { file_path => $ENV{FP}, old_string => $ENV{OLD}, new_string => $ENV{NEW} },
        });')"
}

write() {
    local name="$1" want="$2" fp="$3" content="$4"
    check "$name" "$want" "$(C="$content" FP="$fp" perl -MJSON::PP -e '
        print JSON::PP->new->utf8->encode({
            tool_name  => "Write",
            tool_input => { file_path => $ENV{FP}, content => $ENV{C} },
        });')"
}

edit "php: added // prose"          2 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    // explains a thing\n}'
edit "php: moved existing //"       0 "$R/app/Foo.php" $'// explains a thing\nclass Foo {\n}' $'class Foo {\n    // explains a thing\n}'
edit "php: deleting a comment"      0 "$R/app/Foo.php" $'// gone\nclass Foo {}' $'class Foo {}'
edit "php: added # prose"           2 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    # explains a thing\n}'
edit "php: prose block comment"     2 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    /* why we do this\n       across lines */\n}'
edit "php: prose in docblock"       2 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    /**\n     * Does the thing carefully.\n     */\n}'
edit "php: @param docblock"         0 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    /**\n     * @param int $a\n     */\n}'
edit "php: @use docblock"           0 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    /**\n     * @use HasFactory<FooFactory>\n     */\n}'
edit "php: @throws docblock"        0 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    /**\n     * @throws RuntimeException\n     */\n}'
edit "php: bare // in empty ctor"   0 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    public function __construct() {\n        //\n    }\n}'
edit "php: attribute"               0 "$R/app/Foo.php" $'class Foo {\n}' $'class Foo {\n    #[Test]\n    public function a() {}\n}'
edit "config/ excluded"             0 "$R/config/session.php" $'return [\n];' $'return [\n    // explains a thing\n];'
edit "ts: added //"                 2 "$R/resources/js/a.ts" 'const a = 1;' $'// explains\nconst a = 1;'
edit "ts: prose doc block"          2 "$R/resources/js/a.ts" 'const a = 1;' $'/**\n * Prose here\n */\nconst a = 1;'
edit "ts: @type doc block"          0 "$R/eslint.config.js" 'export default [];' $'/** @type {Linter.Config[]} */\nexport default [];'
edit "ts: multiline @type block"    0 "$R/resources/js/a.ts" 'const a = 1;' $'/**\n * @type {number}\n */\nconst a = 1;'
edit "ts: chisel region marker"     0 "$R/resources/js/types/auth.ts" 'type A = 1;' $'/* @chisel-passkeys */\ntype A = 1;\n/* @end-chisel-passkeys */'
edit "ts: third-party credit"       0 "$R/resources/js/hooks/use-clipboard.ts" 'const a = 1;' $'// Credit: https://usehooks-ts.com/\nconst a = 1;'
edit "ts: @vitest-environment"      0 "$R/resources/js/a.ts" 'const a = 1;' $'// @vitest-environment jsdom\nconst a = 1;'
edit "tsx: added //"                2 "$R/resources/js/b.tsx" 'const a = 1;' $'// explains\nconst a = 1;'
edit "tsconfig.json excluded"       0 "$R/tsconfig.json" '{}' $'{\n  // "strict": true,\n}'
edit "public/index.php excluded"    0 "$R/public/index.php" '<?php' $'<?php\n// Bootstrap Laravel...'
edit "vendored ui/ excluded"        0 "$R/resources/js/components/ui/alert.tsx" 'const a = 1;' $'// explains\nconst a = 1;'
edit "json5: added //"              2 "$R/infection.json5" $'{\n}' $'{\n  // explains\n}'
edit "blade: curly comment"         2 "$R/resources/views/app.blade.php" '<html></html>' $'{{-- explains --}}\n<html></html>'
edit "blade: html comment"          2 "$R/resources/views/app.blade.php" '<html></html>' $'<!-- explains -->\n<html></html>'
edit "blade: no comment"            0 "$R/resources/views/app.blade.php" '<html></html>' '<html><body></body></html>'
edit "sh: added #"                  2 "$R/bin/x.sh" 'echo hi' $'# explains\necho hi'
edit "sh: shebang"                  0 "$R/bin/x.sh" 'echo hi' $'#!/usr/bin/env bash\necho hi'
edit "sh: shellcheck"               0 "$R/bin/x.sh" 'echo hi' $'# shellcheck disable=SC2086\necho hi'
edit "yaml: added #"                2 "$R/deptrac.yaml" 'a: 1' $'# explains\na: 1'
edit "nix: not covered"             0 "$R/nix/quality.nix" '{}' $'{\n  # explains\n}'
edit "md: not covered"              0 "$R/CONTEXT.md" '# Hi' $'# Hi\n<!-- explains -->'
edit "no extension"                 0 "$R/Makefile" 'a:' $'# explains\na:'

write "write: new file with comment" 2 "$R/app/Nope.php" $'<?php\n// explains\n'
write "write: new file clean"        0 "$R/app/Nope.php" $'<?php\nclass Nope {}\n'

check "multiedit: comment in 2nd edit" 2 "{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"$R/app/Foo.php\",\"edits\":[{\"old_string\":\"a\",\"new_string\":\"b\"},{\"old_string\":\"c\",\"new_string\":\"// explains\\nc\"}]}}"
check "multiedit: no comment"          0 "{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"$R/app/Foo.php\",\"edits\":[{\"old_string\":\"a\",\"new_string\":\"b\"}]}}"
check "read: ignored"                  0 "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$R/app/Foo.php\"}}"

echo
echo "passed $pass, failed $fail"
[[ $fail -eq 0 ]]
