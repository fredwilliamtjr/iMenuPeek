#!/bin/zsh
# 「前往上一层级目录」:在当前文件浏览器里上一层(不开新窗、不打断你)。
# - 前台是 Finder:用 AppleScript 把前台 Finder 窗口切到父目录(需「自动化 › Finder」授权,一次性)。
# - 前台是别的 App(如上传/打开对话框):iMenuPeek 不申请「辅助功能」,无法替你发 ⌘↑;
#   脚本只提示用 ⌘↑ 本身。
# 右键文件夹空白处触发;$1 = 当前文件夹路径。
cur="${1:-$PWD}"
parent="${cur:h}"

bid=$(lsappinfo info -only bundleid "$(lsappinfo front 2>/dev/null)" 2>/dev/null)

if [[ "$bid" == *com.apple.finder* ]]; then
  [[ "$parent" == "$cur" ]] && exit 0   # 已在根,无上一层
  osascript - "$parent" <<'APPLESCRIPT'
on run argv
  set parentPath to item 1 of argv
  tell application "Finder"
    if (count of Finder windows) is 0 then return
    set target of front Finder window to (POSIX file parentPath as alias)
  end tell
end run
APPLESCRIPT
else
  print -u2 "Fora do Finder (ex.: janela de abrir/salvar), use ⌘↑ para subir um nível."
  exit 1
fi
