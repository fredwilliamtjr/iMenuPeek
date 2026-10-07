#!/bin/zsh
# 「Ocultar / Reexibir」:inverte o atributo "oculto" (UF_HIDDEN, o mesmo do chflags) de cada item selecionado.
# Item visível → oculto; item oculto → visível. Para reexibir, mostre os ocultos no Finder (⌘⇧.) e use a ação nele.
# -h/lstat: num link simbólico mexe no próprio link, não no destino. (chflags não aceita "--":
# depois do atributo tudo já é caminho, inclusive nome começando com "-".)
hidden=0; shown=0; failed=0
for item in "$@"; do
  if ! flags=$(/usr/bin/stat -f '%f' -- "$item" 2>/dev/null); then
    print -u2 -- "$item"; (( failed++ )); continue
  fi
  if (( flags & 0x8000 )); then
    if /usr/bin/chflags -h nohidden "$item"; then (( shown++ )); else (( failed++ )); fi
  else
    if /usr/bin/chflags -h hidden "$item"; then (( hidden++ )); else (( failed++ )); fi
  fi
done
case "${MENUMATE_LOCALE:-en}" in
  zh*) echo "已隐藏 $hidden · 已显示 $shown" ;;
  pt*) echo "Ocultados: $hidden · Reexibidos: $shown" ;;
  *)   echo "Hidden: $hidden · Shown: $shown" ;;
esac
(( failed == 0 ))
