#!/bin/zsh
# 「前往上一层级目录」(右键文件/文件夹时触发,与右键空白处的同名动作互补,行为一致=上一层)。
# - 前台是 Finder:把前台窗口切到"当前所在文件夹的上一层"(不开新窗、不打断你)。
# - 前台是别的 App(如上传/打开对话框):iMenuPeek 不申请「辅助功能」,只提示用 ⌘↑ 本身。
# 需要的授权:「自动化 › Finder」(一次性,首次引导「授予权限」里授予)。

bid=$(lsappinfo info -only bundleid "$(lsappinfo front 2>/dev/null)" 2>/dev/null)

if [[ "$bid" == *com.apple.finder* ]]; then
  osascript <<'APPLESCRIPT'
tell application "Finder"
  if (count of Finder windows) is 0 then return
  set w to front Finder window
  try
    set target of w to (container of (target of w))   -- 当前文件夹的上一层
  end try
end tell
APPLESCRIPT
else
  print -u2 "Fora do Finder (ex.: janela de abrir/salvar), use ⌘↑ para subir um nível."
  exit 1
fi
