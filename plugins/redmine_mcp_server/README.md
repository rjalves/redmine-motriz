# Redmine MCP Server

Servidor **MCP** (Model Context Protocol) embutido no Redmine 7. Assistentes de IA
consultam e editam o Redmine em nome de cada pessoa, **dentro das permissões que
ela já tem**.

Implementa a revisão **2026-07-28** da especificação.

## O que expõe

| Ferramenta | Permissão exigida |
|---|---|
| `search` | `search_project` |
| `list_projects`, `get_project` | `view_project` |
| `list_issues`, `get_issue` | `view_issues` |
| `list_time_entries` | `view_time_entries` |
| `get_wiki_page` | `view_wiki_pages` |
| `list_enumerations` | — (metadados de configuração) |
| `create_issue` | `add_issues` |
| `update_issue` | `edit_issues` |
| `add_issue_note` | `add_issue_notes` |
| `log_time` | `log_time` |

A lista **muda por usuário**: quem não pode criar tarefa nem enxerga
`create_issue`. A especificação autoriza isso — o conjunto de tools *"MAY vary by
the authorization presented on the request"*.

## Como a permissão é garantida

Não há modelo de permissão novo. Os escopos OAuth do Redmine **são** os nomes das
permissões (`config/initializers/30-redmine.rb:52` registra as 80 como
`optional_scopes`), e `Role#allowed_to?(action, @oauth_scope)` já intersecta o
escopo do token com as permissões do papel. O plugin só chama
`User.current.allowed_to?` e não estraga o que o core faz.

Consequência prática: um token com escopo `view_issues` recebe recusa ao tentar
`log_time`, mesmo que a pessoa tenha essa permissão no Redmine.

## Instalação

### 1. Plugin

```bash
cp -r redmine_mcp_server /caminho/do/redmine/plugins/
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Não há gems novas: é JSON-RPC sobre uma rota Rails comum, e a autenticação
reaproveita o Doorkeeper que o Redmine já embarca.

### 2. Ligar a API REST — obrigatório

**Administração → Configurações → API → Habilitar serviço web REST.**

Sem isso **nenhum token funciona**: `find_current_user` só chega ao ramo do
Doorkeeper se `Setting.rest_api_enabled?`
(`app/controllers/application_controller.rb:130`). O padrão do Redmine é
desligado. A tela de configuração do plugin avisa quando está assim.

### 3. Ligar o plugin

**Administração → Plugins → Redmine MCP Server → Configurar.**

| Campo | Efeito |
|---|---|
| Habilitar o servidor MCP | Desligado, o endpoint responde 503 |
| Registro automático de clientes | Deixa o conector obter um `client_id` sozinho (RFC 7591) |
| Limite de chamadas por minuto | Padrão 60, por usuário |
| Retenção da auditoria | Dias; expurgo por `rake redmine_mcp_server:purge_audit` |

### 4. Cada pessoa se habilita

Em **Minha conta** aparece o bloco "Servidor MCP", com a URL de conexão e o botão
de habilitar. Enquanto a pessoa não habilitar, o endpoint recusa o token dela com
403.

## Conectar o Claude

Adicione um conector remoto apontando para:

```
https://SEU_DOMINIO/mcp
```

A URL é a mesma para todo mundo e **não contém segredo** — a especificação proíbe
token em query string. Quem identifica a pessoa é o fluxo OAuth que o conector
percorre: ele descobre o authorization server pelo `WWW-Authenticate` do 401,
abre o consentimento no próprio Redmine e recebe um token em nome dela.

### Se o registro automático estiver desligado

O conector não consegue obter um `client_id` sozinho. Nesse caso, o administrador
cria a aplicação em **Administração → Aplicações OAuth**:

- **Redirect URI:** a que o cliente informar (o Claude mostra na tela do conector)
- **Escopos:** `view_project search_project view_members view_issues add_issues
  edit_issues add_issue_notes view_time_entries log_time view_wiki_pages`

e a pessoa cola `client_id` e `client_secret` na configuração avançada do conector.

## Endpoints

| Caminho | Para quê |
|---|---|
| `POST /mcp` | O endpoint JSON-RPC. Só POST |
| `GET /.well-known/oauth-protected-resource` | RFC 9728 — onde autenticar |
| `GET /.well-known/oauth-authorization-server` | RFC 8414 — descreve o Doorkeeper |
| `POST /mcp/register` | RFC 7591 — registro dinâmico, se ligado |

## Segurança

| Risco | Defesa |
|---|---|
| Token de outro recurso | Validação de audience; escopos limitados aos anunciados |
| DNS rebinding | Header `Origin` validado; 403 se desconhecido |
| Enumeração de ferramentas | Ferramenta sem permissão responde "Unknown tool", igual a inexistente |
| Enumeração de tarefas | "not found or not visible" é a mesma mensagem para os dois casos |
| Nota privada vazando | `Issue#visible_journals_with_index`, que aplica `view_private_notes` |
| Laço descontrolado do modelo | Limite por usuário e minuto |
| Vazamento pela auditoria | A tabela guarda os **nomes** dos argumentos, nunca os valores |

**Aprovação humana** fica com o cliente: cada ferramenta declara `readOnlyHint`,
`destructiveHint` e `idempotentHint`, e o conector do Claude usa isso para pedir
confirmação antes de executar. `update_issue` é a única marcada como destrutiva.

## Diagnóstico

### Toda chamada volta 401

A API REST está desligada, ou a pessoa não habilitou o MCP em Minha conta. O corpo
do 401 diz qual dos dois.

### O conector não consegue autenticar

Confira que os dois `.well-known` respondem:

```bash
curl -s https://SEU_DOMINIO/.well-known/oauth-protected-resource | jq
curl -s https://SEU_DOMINIO/.well-known/oauth-authorization-server | jq
```

Atrás de proxy (Cloudflare, nginx), o proxy precisa enviar
`X-Forwarded-Proto: https`, senão as URLs saem em `http://` e o cliente recusa.

### `-32020 HeaderMismatch`

O cliente mandou `Mcp-Method` ou `Mcp-Name` divergente do corpo. É exigência da
revisão 2026-07-28 e a validação é intencional: sem ela, um balanceador poderia
rotear por um valor enquanto o servidor executa outro.

### O limite de chamadas não está limitando

O contador vive no `Rails.cache`. Com `:null_store` ele não tem onde contar — o
plugin registra `MCP: Rails.cache is a NullStore — tool call rate limiting is
INACTIVE.` no log e deixa passar. Com mais de um processo Puma e cache em
memória, cada processo conta o seu; use um store compartilhado se precisar de
precisão.

## Testes

```bash
docker build -f docker/Dockerfile.test -t redmine-motriz:sso-test .
docker run --rm -e PLUGIN=redmine_mcp_server redmine-motriz:sso-test
```

## Fora de escopo

Anexos; escrita em wiki; versões, categorias e marcos; `resources/` e `prompts/`
do MCP; confirmação servidor-adentro (MRTR/elicitation); clientes além do Claude.
