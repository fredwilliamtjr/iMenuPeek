# Segurança

## Como reportar uma vulnerabilidade

Use os **GitHub Security Advisories** do repositório (Security → *Report a vulnerability*), não uma issue pública.

## Modelo de ameaça e decisões de projeto

O iMenuPeek é um app **sem sandbox** com uma extensão Finder Sync **com sandbox**. A postura de segurança decorre dessa divisão.

- **Os scripts rodam como você.** Presets, ações suas e ações de pacotes importados são scripts `zsh` executados com as suas permissões de usuário — o mesmo nível de confiança de qualquer coisa que você rode no Terminal. Só ative ações e pacotes cujos scripts você leu. Os scripts são chamados como `/bin/zsh "$script" "$@"`, com as entradas passadas como argumentos/`MENUMATE_PATHS`; o app nunca faz `eval` nem interpola caminhos selecionados num comando.

- **Pedidos de ação são autenticados (iMenuPeek).** A extensão manda os cliques ao app pela `DistributedNotificationCenter`, que qualquer processo pode escutar e postar — inclusive apps com sandbox. Por isso cada pedido é assinado com HMAC-SHA256 usando uma chave gerada por instalação em `~/Library/Application Support/iMenuPeek/IPC/ipc.key` (pasta 0700, arquivo 0600):
  - apps de terceiros com sandbox não leem esse arquivo; a extensão lê por uma exceção de sandbox somente leitura restrita à pasta `IPC/`;
  - quem escuta um pedido legítimo não consegue forjar outro (sem a chave) nem repeti-lo (janela de 30 s + nonce de uso único);
  - pedido sem assinatura válida é recusado e registrado no log do sistema;
  - além disso, todo clique continua sendo revalidado contra a configuração local: a ação precisa existir, estar ativa e os caminhos precisam existir.

  Processos sem sandbox do mesmo usuário conseguem ler a chave, mas esses já têm acesso equivalente aos seus arquivos.

- **O snapshot app → extensão não é fronteira de privilégio.** O app envia a configuração do menu à extensão pela mesma `DistributedNotificationCenter`, legível por processos do mesmo usuário. Um snapshot forjado só muda a *aparência* do menu; não executa nada, porque o clique precisa ser assinado e é revalidado contra a configuração local.

- **Sem presets que movem arquivos.** Os presets Cut/Paste do MenuMate foram removidos: eram ações ativadas por padrão que moviam arquivos e podiam ser disparadas sem clique do usuário.

- **Sem Acessibilidade.** O iMenuPeek não pede a permissão de Acessibilidade: scripts são processos filhos do app e herdariam o poder de sintetizar teclas e controlar outros apps. Ele pede apenas Notificações (avisar falhas) e Automação › Finder (navegar na janela do Finder). Não exige Acesso Total ao Disco.

- **Sem atualização automática.** O Sparkle foi removido; o app não consulta nenhum feed de atualização. Versões novas saem só pelas Releases do GitHub.

- **Pacotes de extensão são somente leitura na importação e vêm desativados.** A importação é um `git clone --depth 1 -- <url>` que **não executa nada** (o `--` impede que a URL digitada vire opção do git). A revisão mostra cada script declarado no manifesto **e todo outro arquivo do repositório** (scripts ocultos, executáveis e binários são sinalizados), porque um script declarado pode fazer `source` de arquivos vizinhos. As ações importadas entram **desativadas** até você ativá-las uma a uma.

- **"Remover quarentena" ignora o Gatekeeper de propósito.** Se você criar uma ação que remove `com.apple.quarantine`, use só em arquivos em que confia.

- **O caminho de autoria por IA edita arquivos locais direto.** A skill [`menumate-author`](skills/menumate-author/SKILL.md) e qualquer editor externo escrevem `config.json` / `Scripts/` diretamente, sem a revisão de pacotes. Trate ações escritas por IA ou por script com o mesmo cuidado de código seu.
