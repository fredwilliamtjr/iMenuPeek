# iMenuPeek

**Menu de botão direito do Finder com ações próprias em script.**

App de barra de menus para macOS: você cria ações (script zsh, inline ou em arquivo, ou "abrir com app"), define quando cada uma aparece (arquivo, pasta, fundo da janela, tipo de arquivo, quantidade de itens) e elas surgem no menu de contexto do Finder. O app principal executa as ações; uma extensão Finder Sync monta o menu.

## Origem

O iMenuPeek é um fork do [MenuMate](https://github.com/Hibrielle/menumate), de Hibrielle, distribuído sob a licença MIT (ver [LICENSE](LICENSE)). O histórico de commits original foi preservado. A documentação original está em [docs/README-menumate.md](docs/README-menumate.md).

Antes do fork, o código do MenuMate (commit `5e424cd`) passou por revisão de segurança: sem telemetria, sem código ofuscado e sem acesso à rede além do que o usuário dispara. Os ajustes deste fork partem dos pontos levantados nessa revisão.

## Situação

Em preparação: o código ainda é o do MenuMate. Os ajustes planejados (nome e identificadores, endurecimento de segurança, remoção da atualização automática, interface em português) entram nas próximas versões.

## Compilar

Requer macOS 13+, Xcode 16+ e Homebrew. O `make build` instala o [XcodeGen](https://github.com/yonaskolb/XcodeGen) se faltar, cria o `Local.xcconfig` a partir do template, gera o projeto e compila.

```bash
make build
```

## Licença

MIT. Copyright (c) 2026 Hibrielle (código original do MenuMate).
