# MenuMate test build / 测试版安装说明

## 简体中文

此包面向测试用户，要求 macOS 13 或更新版本，包含 Apple Silicon 与 Intel 两种架构。
App 和 Finder 扩展使用临时签名（ad-hoc），**没有 Developer ID 签名，也没有 Apple 公证**。
因此 macOS 首次打开时可能拦截；这不等于已经确认安装包损坏，也不能据此忽略真正的安全告警。

1. 从 [MenuMate GitHub Releases](https://github.com/Hibrielle/menumate/releases) 下载 DMG。
   同时下载 `SHA256SUMS.txt`，在下载目录执行 `shasum -a 256 MenuMate-*-universal.dmg`，与文件中的对应值比较。
2. 打开 DMG，把 **MenuMate.app** 拖到 **Applications（应用程序）**。若已有旧版，先退出旧版再替换；配置保存在用户资源库内。
3. 从应用程序打开 MenuMate。如果系统拦截，在确认下载来源和校验值后，打开 **系统设置 → 隐私与安全性 → 仍要打开**，按系统提示确认。[Apple 官方说明](https://support.apple.com/102445)
4. MenuMate 是菜单栏 App，不常驻 Dock。点击菜单栏图标打开设置，并按引导启用 **Finder 扩展**。较新系统在“通用 → 登录项与扩展 → Finder 扩展”；其他版本可在系统设置搜索“扩展”。
5. 在本地普通文件夹选中文件并右键，验证“复制路径”等已启用动作。第一次执行特定动作可能需要额外授权。受系统管理的目录、云盘以及公司设备策略可能限制扩展。

如果“仍要打开”没有出现，请先确认 `.app` 已复制到应用程序，并从那里尝试打开一次。
仅当你信任此测试包、校验值匹配，而且不是系统明确提示恶意软件时，可自行选择执行以下命令，移除 **这一份 App** 的下载隔离标记，再重试打开：

```sh
xattr -dr com.apple.quarantine "/Applications/MenuMate.app"
```

这不是 Apple 公证，也不会把测试版变成正式签名版。不要全局关闭 Gatekeeper 或 SIP。
如果问题仍存在，请提交系统版本、芯片类型和错误截图到 [Issues](https://github.com/Hibrielle/menumate/issues)，不要提供个人文件或密钥。

自动更新在测试包中关闭；更新时下载新的 DMG 并替换 App。临时签名的更新可能需要重新确认权限或重新启用扩展。
本包包含双架构代码，但不能把本机验证视为所有系统、Intel 机器或首次下载环境均已验证。

## English

Requires macOS 13 or later. The Universal app includes Apple Silicon and Intel code.
The app and Finder extension are **ad-hoc signed, not Developer ID signed or Apple-notarized**.
Gatekeeper may block the first launch. This does not establish that the download is damaged,
and genuine malware warnings should not be ignored.

1. Download the DMG and `SHA256SUMS.txt` from [GitHub Releases](https://github.com/Hibrielle/menumate/releases).
   In the download directory, run `shasum -a 256 MenuMate-*-universal.dmg` and compare the matching entry.
2. Open the DMG and drag **MenuMate.app** into **Applications**. Quit an existing copy before replacing it; configuration lives separately in your user Library.
3. Open the app from Applications. If blocked, verify the source and checksum, then use **System Settings → Privacy & Security → Open Anyway** and follow the prompts. See [Apple's instructions](https://support.apple.com/102445).
4. Open Settings from MenuMate's menu-bar icon and enable its Finder extension. Recent systems use **General → Login Items & Extensions → Finder Extensions**; on other versions search System Settings for “Extensions”.
5. Select a file in a normal local folder and right-click to check enabled actions such as Copy Path. Individual actions can request permissions when first used; system-managed locations, cloud providers and device policies can restrict extensions.

If Open Anyway is absent, first confirm the app was copied into Applications and attempted to launch there.
Only if you trust this test build, its checksum matches, and macOS is not reporting known malware,
you may choose to remove the download quarantine attribute from **this app only**:

```sh
xattr -dr com.apple.quarantine "/Applications/MenuMate.app"
```

This does not notarize the app. Do not disable Gatekeeper or SIP globally. Report persistent problems,
with macOS version, chip type and an error screenshot, in [Issues](https://github.com/Hibrielle/menumate/issues).
Do not include private files or credentials.

Automatic updates are disabled. Download another DMG to update; ad-hoc updates may require permissions
or the Finder extension to be enabled again. Universal architecture verification does not constitute
runtime testing on every OS version, Intel hardware or a fresh downloaded installation.
