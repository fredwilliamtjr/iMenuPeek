# Publicando o iMenuPeek

O iMenuPeek **não tem atualização automática**: o Sparkle do MenuMate foi removido. Versão nova = release no GitHub, baixada e instalada à mão.

Há três caminhos: **versão final ad-hoc** (o padrão da família Peek), build de teste e release formal (Developer ID + notarização).

## Versão final (ad-hoc) — padrão

Com tudo commitado:

```bash
zsh scripts/build_release.sh 0.1.0
```

Gera em `dist/` o `iMenuPeek.app`, o `iMenuPeek.dmg` (arrastar para Aplicativos), o `iMenuPeek.zip` e o `SHA256SUMS.txt`. Universal (arm64 + x86_64), assinatura ad-hoc, sem notarização; o script confere arquiteturas, assinatura, versão e ausência de Sparkle. Depois publique a release no GitHub com a tag `v0.1.0` anexando o DMG e o zip.

## Build de teste (ad-hoc, sem notarização)

Com o código desejado commitado, rode:

```bash
zsh scripts/release-test.sh 0.1.0-beta.1
```

O script gera um app Universal em Release com assinatura ad-hoc, confere as duas arquiteturas e as assinaturas, e cria em `build/test-release/<versão>/` o DMG, as instruções de instalação, os metadados de build e os hashes SHA-256. Ele não publica nem notariza. Veja as [instruções de instalação de teste](INSTALL-TEST.md).

Depois de conferir o artefato, crie a tag nesse mesmo commit e uma **Pre-release** no GitHub com o DMG, `SHA256SUMS.txt`, `BUILD-INFO.txt` e `INSTALL.md`. Não descreva build ad-hoc como notarizado. O workflow de release assinada ignora tags com `-` (pré-release).

## Release formal (Developer ID)

Exige assinatura paga do **Apple Developer Program** e um certificado **Developer ID Application**. O certificado "Apple Development" (gratuito) serve para compilar e rodar localmente, mas **não** para notarizar.

### Preparação (uma vez)

1. **Certificado Developer ID:** crie no Xcode (Ajustes → Contas) ou no portal da Apple e instale no Keychain. Para achar a identidade:

   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

2. **Credenciais de notarização:** no App Store Connect (Usuários e Acesso → Integrações), crie uma **API Key** (função Developer) e baixe o `AuthKey_XXXXXX.p8`. Para uso local, guarde um perfil do notarytool:

   ```bash
   xcrun notarytool store-credentials imenupeek-notary \
     --key AuthKey_XXXXXX.p8 --key-id <KEY_ID> --issuer <ISSUER_ID>
   ```

3. **Segredos do GitHub Actions** (para o [`release.yml`](../.github/workflows/release.yml)), em Settings → Secrets and variables → Actions:

   | Segredo | Conteúdo |
   |---|---|
   | `DEVELOPER_ID_CERT_P12_BASE64` | certificado + chave exportados em `.p12`, em `base64` |
   | `DEVELOPER_ID_CERT_PASSWORD` | senha do `.p12` |
   | `KEYCHAIN_PASSWORD` | qualquer texto (keychain temporário do CI) |
   | `DEVELOPER_ID_APP` | `Developer ID Application: Seu Nome (TEAMID)` |
   | `TEAM_ID` | Team ID da Apple |
   | `NOTARY_KEY_ID` / `NOTARY_ISSUER` | da API Key acima |
   | `NOTARY_KEY_P8_BASE64` | o `AuthKey_XXXXXX.p8` em `base64` |

### Gerando a release

Localmente:

```bash
export DEVELOPER_ID_APP="Developer ID Application: Seu Nome (TEAMID)"
export TEAM_ID=TEAMID
export NOTARY_PROFILE=imenupeek-notary
make release VERSION=1.0.0
```

Gera o archive (Release, hardened runtime), exporta o app Developer ID, monta o DMG assinado, notariza e grampeia. Artefato: `build/release/iMenuPeek-1.0.0.dmg`.

Pelo CI: crie e envie a tag (`git tag v1.0.0 && git push origin v1.0.0`). O `release.yml` compila, assina, notariza e cria a release no GitHub com o DMG.

### Checklist

- [ ] A tag corresponde à versão e ao commit pretendidos.
- [ ] Os sete segredos do GitHub estão configurados (para o CI).
- [ ] `xcrun stapler validate build/release/iMenuPeek-<v>.dmg` passa.
- [ ] Gatekeeper numa máquina limpa: `spctl -a -vvv -t install iMenuPeek-<v>.dmg`.
