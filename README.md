# Dr Island

Central de controlo do dia de trabalho, no notch do MacBook: mostra o uso do **Claude**, os teus **Pull Requests** (GitHub), as tasks do **Jira**, música, temporizador de foco e atalhos de apps. Com o rato por cima do notch, a ilha expande.

> Para a lista completa de funcionalidades e regras, ver [docs/funcionalidades.md](docs/funcionalidades.md).

## Requisitos

- macOS 14 ou superior (funciona em ecrãs sem notch, com uma pílula no topo).
- Cada integração é opcional e só precisa do que está descrito abaixo.

| Integração | O que precisas |
|---|---|
| **Claude** | Claude Code instalado e com sessão iniciada neste Mac |
| **GitHub** | GitHub CLI (`gh`) instalado e autenticado |
| **Jira** | Site Jira Cloud, o teu email e um token de API |

## Instalar

**Com o DMG:**

1. Abre o `DrIsland-<versão>.dmg` e arrasta a app para **Aplicações**.
2. Na primeira abertura, clica com o botão direito na app → **Abrir** (a app não está notarizada, por isso o macOS pede confirmação).
3. Em **Definições → Geral** liga o arranque no login, se quiseres.

**A partir do código** (precisa das Command Line Tools ou do Xcode):

```bash
scripts/bundle.sh release   # gera DrIsland.app
scripts/dmg.sh              # gera o DMG
```

## Configurar

Abre as **Definições** pelo ícone da barra de menu (⌘,).

### Claude

Não há nada a configurar. A app lê o token do Claude Code que já está no teu Keychain e mostra o uso da sessão (5 h) e da semana.

- Se aparecer "sem credenciais", abre o Claude Code no terminal e faz `/login`.
- Se o Keychain pedir permissão, escolhe **Permitir sempre**.

### GitHub

A app usa o `gh`; não guarda tokens.

```bash
brew install gh
gh auth login
```

Em **Definições → GitHub** podes limitar a org/repositório (ex.: `doutorfinancas`). A app encontra o `gh` em `/opt/homebrew/bin` ou `/usr/local/bin`; noutro sítio, indica o caminho nas Definições.

### Jira

Desligado por defeito. Em **Definições → Jira**:

1. Cria um token em <https://id.atlassian.com/manage-profile/security/api-tokens>.
2. Preenche **Site** (`empresa.atlassian.net`), **Email** (o da tua conta Atlassian) e cola o **token**. Fica guardado só no Keychain.
3. Carrega em **Testar** e liga o Jira.

As tasks vêm do JQL configurado (por omissão, as que estão atribuídas a ti e por concluir). O bloco "Aprovações" usa o campo personalizado `customfield_10127` da instância da Doutor Finanças; noutra instância, ajusta o JQL nas Definições.

## Problemas comuns

- **Os PRs não aparecem:** corre `gh auth status` no terminal.
- **Sem avisos do macOS:** a app tem de estar instalada como `.app` e com notificações permitidas.
- **Não incomodar com o Focus do macOS:** precisa de Acesso Total ao Disco.
- **Registo de erros:** menu da barra → **Registo de erros…**.

## Desenvolvimento

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

`swift build` simples falha por falta do plugin de macros do SwiftUI; usa `scripts/bundle.sh`.
