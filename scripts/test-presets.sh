#!/bin/zsh
# 预设脚本的确定性行为测试(不依赖 Finder/剪贴板,CI 可跑)。
# 覆盖:new-file 模板复制 + 自动重名编号。
set -euo pipefail
ROOT="${0:A:h:h}"
PRESETS="$ROOT/App/PresetScripts"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# 屏蔽 new-file 里的 `open -R`(测试环境不弹 Finder)
stub="$T/bin"; mkdir -p "$stub"; printf '#!/bin/zsh\nexit 0\n' > "$stub/open"; chmod +x "$stub/open"
export PATH="$stub:$PATH"

fail() { print -u2 "FAIL: $1"; exit 1 }

# --- new-file: 模板复制 + 自动编号 ---
tpl="$T/templates"; mkdir -p "$tpl"; print "hello" > "$tpl/Note.md"
work="$T/work"; mkdir -p "$work"
MENUMATE_TEMPLATES="$tpl" MENUMATE_VARIANT="Note.md" /bin/zsh "$PRESETS/new-file.sh" "$work" >/dev/null
[[ -f "$work/Note.md" ]] || fail "new-file 未创建 Note.md"
MENUMATE_TEMPLATES="$tpl" MENUMATE_VARIANT="Note.md" /bin/zsh "$PRESETS/new-file.sh" "$work" >/dev/null
[[ -f "$work/Note 2.md" ]] || fail "new-file 未自动编号为 'Note 2.md'"

# --- toggle-hidden: inverte o atributo oculto, inclusive com espaço no nome ---
hid="$T/hid"; mkdir -p "$hid"; print a > "$hid/a b.txt"; print b > "$hid/c.txt"
chflags hidden "$hid/c.txt"
out=$(MENUMATE_LOCALE=pt-BR /bin/zsh "$PRESETS/toggle-hidden.sh" "$hid/a b.txt" "$hid/c.txt") || fail "toggle-hidden falhou"
(( $(stat -f '%f' "$hid/a b.txt") & 0x8000 )) || fail "toggle-hidden não ocultou 'a b.txt'"
(( $(stat -f '%f' "$hid/c.txt") & 0x8000 )) && fail "toggle-hidden não reexibiu 'c.txt'"
[[ "$out" == "Ocultados: 1 · Reexibidos: 1" ]] || fail "toggle-hidden mensagem inesperada: $out"
MENUMATE_LOCALE=pt-BR /bin/zsh "$PRESETS/toggle-hidden.sh" "$hid/a b.txt" >/dev/null
(( $(stat -f '%f' "$hid/a b.txt") & 0x8000 )) && fail "toggle-hidden não reverteu 'a b.txt'"
MENUMATE_LOCALE=pt-BR /bin/zsh "$PRESETS/toggle-hidden.sh" "$hid/inexistente" >/dev/null 2>&1 && fail "toggle-hidden deveria falhar com item inexistente"

print "✓ preset scripts: new-file (auto-number) + toggle-hidden pass"
