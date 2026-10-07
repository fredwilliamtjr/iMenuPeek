#!/bin/zsh
# 复制选中项的绝对路径到剪贴板（多选按行拼接）
printf '%s\n' "$@" | pbcopy
case "${MENUMATE_LOCALE:-en}" in
  zh*) echo "已复制 $# 个路径" ;;
  pt*) echo "$# caminho(s) copiado(s)" ;;
  *)   echo "Copied $# path(s)" ;;
esac
