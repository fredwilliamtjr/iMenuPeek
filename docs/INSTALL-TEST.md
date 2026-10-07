# iMenuPeek — instalação da versão de teste

Requer macOS 13 ou mais novo. O app Universal inclui código para Apple Silicon e Intel.
O app e a extensão do Finder têm **assinatura ad-hoc, sem Developer ID e sem notarização da Apple**.
O Gatekeeper pode bloquear a primeira abertura. Isso não quer dizer que o download esteja danificado,
e alertas reais de malware não devem ser ignorados.

1. Baixe o DMG e o `SHA256SUMS.txt` nas [Releases do GitHub](https://github.com/fredwilliamtjr/iMenuPeek/releases).
   Na pasta do download, rode `shasum -a 256 iMenuPeek-*-universal.dmg` e compare com a linha correspondente.
2. Abra o DMG e arraste o **iMenuPeek.app** para **Aplicativos**. Encerre a cópia antiga antes de substituir; a configuração fica separada, na sua pasta Biblioteca.
3. Abra o app a partir de Aplicativos. Se for bloqueado, confira a origem e o checksum e use **Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo Assim**. Veja as [instruções da Apple](https://support.apple.com/pt-br/102445).
4. Abra os Ajustes pelo ícone do iMenuPeek na barra de menus e ative a extensão do Finder. Em sistemas recentes fica em **Geral → Itens de Início e Extensões → Extensões do Finder**; em outras versões, procure "Extensões" nos Ajustes do Sistema.
5. Selecione um arquivo numa pasta local comum e clique com o botão direito para conferir as ações ativas, como Copiar caminho. Algumas ações pedem permissão no primeiro uso; locais gerenciados pelo sistema, provedores de nuvem e políticas do aparelho podem restringir extensões.

Se "Abrir Mesmo Assim" não aparecer, confirme primeiro que o app foi copiado para Aplicativos e que você tentou abri-lo de lá.
Só se você confiar nesta versão de teste, o checksum bater e o macOS não estiver apontando malware conhecido,
você pode remover o atributo de quarentena **apenas deste app**:

```sh
xattr -dr com.apple.quarantine "/Applications/iMenuPeek.app"
```

Isso não notariza o app. Não desative o Gatekeeper nem o SIP de forma global. Problemas persistentes podem ser
relatados, com versão do macOS, tipo de chip e captura do erro, nas [Issues](https://github.com/fredwilliamtjr/iMenuPeek/issues).
Não inclua arquivos pessoais nem credenciais.

Não há atualização automática. Para atualizar, baixe o DMG novo; atualizações com assinatura ad-hoc podem exigir
reconceder permissões ou reativar a extensão do Finder. Verificar a arquitetura Universal não equivale a testar
em todas as versões do macOS, em Macs Intel ou numa instalação recém-baixada.
