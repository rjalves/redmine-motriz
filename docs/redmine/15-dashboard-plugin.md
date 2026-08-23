# Diagnóstico — plugin `dashboard` (akpaevj)

Repositório: https://github.com/akpaevj/dashboard
Versão analisada: **1.0.11** — commit `60bd64a`, 23/04/2025. Licença **MIT**.

## Veredito

**Compatível com a instância do servidor.** Instala e roda sem alteração de código.
Não pede gem nenhuma, não tem migração, e todas as APIs do Redmine que ele usa
continuam existindo no 7.0.0. Convive com o plugin `motriz_2` sem conflito.

Há quatro ressalvas antes de subir em produção — a primeira é de segurança e
merece correção (seção "O que ajustar").

## O que o plugin faz

Acrescenta um item "Dashboard" no menu superior com um quadro estilo kanban:
uma coluna por situação de tarefa, um cartão por tarefa, arrastar o cartão muda a
situação. Cores por situação e por projeto são configuráveis, com um botão que
gera a paleta automaticamente em HSL.

São **547 linhas** no total, distribuídas assim:

| Arquivo | Linhas | Papel |
|---|---|---|
| `assets/stylesheets/style.css` | 199 | todo o visual do quadro |
| `app/controllers/dashboard_controller.rb` | 101 | duas ações: `index` e `set_issue_status` |
| `app/views/settings/_dashboard_settings.erb` | 69 | tela de configuração |
| `assets/javascripts/script.js` | 69 | troca de projeto e arrastar-soltar |
| `app/views/dashboard/index.html.erb` | 65 | o quadro |
| `assets/javascripts/settings.js` | 42 | gerador de cores |
| `app/helpers/dashboard_helper.rb` | 2 | vazio |

Mais `Sortable.min.js` 1.13.0 (MIT) embutido e 8 traduções — inclusive **pt-BR**, completa.

Sem `Gemfile`, sem `db/migrate`. Instalar é copiar a pasta; desinstalar é apagá-la.
Nada é gravado no banco enquanto ninguém salvar a tela de configuração.

## Como a compatibilidade foi verificada

Não por leitura: o plugin foi **carregado e executado contra o Redmine real do
servidor**, num contêiner descartável criado a partir da mesma imagem de produção
(`redmine-motriz-redmine`), na mesma rede, apontando para o mesmo banco **somente
em leitura**, com o entrypoint substituído para não rodar migração.

O contêiner de produção nunca foi tocado — antes e depois, `plugins/` continha
apenas `motriz_2` e `redmine_google_sso`. Os arquivos temporários foram removidos.

Alvo: **Redmine 7.0.0 stable · Rails 8.1.3 · Ruby 3.4.10 · PostgreSQL 16**.

### Resultado

| Verificação | Resultado |
|---|---|
| `Redmine::Plugin.all` reconhece `:dashboard` | Dashboard 1.0.11 |
| Rotas desenhadas | `GET /dashboard`, `GET /dashboard/set_issue_status/:issue_id/:status_id` |
| Item no menu superior | `[:dashboard, :home, :my_page, :projects, :administration, :help]` |
| `_dashboard_settings.erb` (sem formato no nome) resolve no Rails 8.1 | sim |
| `plugin_assets/dashboard/{style.css,script.js,Sortable.min.js,settings.js}` no Propshaft | os quatro |
| `GET /dashboard` como admin | **HTTP 200**, 54.609 bytes, quadro renderizado |
| `GET /settings/plugin/dashboard` | **HTTP 200**, 6 campos de cor por situação, 5 por projeto |
| CSS/JS com digest servidos | `style-c328e22b.css`, `Sortable.min-921293e8.js` |
| Anônimo em `/dashboard` | 302 → `/login` (a instância tem `login_required`) |
| pt-BR carregado | "Cores das Situações", "Não definido" |

Todas as APIs do Redmine usadas pelo controller responderam na instância:
`IssueStatus.sorted`, `Project.visible`, `Issue.visible`, `Issue.visible.open`,
`project.children`, `new_statuses_allowed_to`, `init_journal`, `User::USER_FORMATS`,
`Setting.plugin_<id>`. O `Issue.visible.where(projects: {id: [...]})` funciona porque
`Issue.visible` já traz `INNER JOIN projects` — confirmado no SQL gerado.

## Convivência com o plugin `motriz_2`

Este era o risco real, porque o `motriz_2` **substitui o layout** `layouts/base.html.erb`.
Um plugin de tela depende de três coisas desse layout, e as três estão lá:

| O que o `dashboard` precisa | Onde está no layout do `motriz_2` |
|---|---|
| `yield :header_tags` — senão o CSS e o JS dele nunca carregam | linha 25 |
| `javascript_heads` — senão não há jQuery e `$(function(){...})` morre | linha 18 |
| `#main-menu` e `#content` — o `script.js` mexe nos dois | linhas 91 e 116 |

Confirmado no HTML renderizado da tela `/dashboard`: jQuery presente, Sortable
presente, `id="main-menu"` presente, `id="content"` presente.

O CSS do plugin também não briga com o tema: os 29 seletores são todos de classe
com prefixo próprio (`.select_project_*`, `.status_column*`, `.issue_card*`),
nenhum seletor de elemento global.

**Única aresta:** no modo "menu drop-down", o `<select>` nativo do plugin apanha o
*preflight* do Tailwind do `motriz_2` e sai sem estilo de navegador. O modo padrão
(botões coloridos) não tem esse problema.

## O que ajustar

### 1. `set_issue_status` muda dados por GET — CSRF

`config/routes.rb` declara a mutação como `GET`, e o `script.js` a chama com um
`fetch` simples. O Rails só valida token anti-CSRF em requisições que não são GET,
então **não há verificação nenhuma** nesse caminho.

Consequência concreta: uma página externa com
`<img src="https://gestao.motriz.tec.br/dashboard/set_issue_status/1234/5">`
muda a situação da tarefa 1234 de qualquer pessoa logada que a visite, e o
histórico registra a mudança no nome dela. Pré-carregadores de link, varredores de
URL de antivírus e prévias de link em e-mail/chat disparam GETs sozinhos.

O impacto é limitado pela permissão — o controller checa
`new_statuses_allowed_to`, que assume `User.current` — então ninguém consegue
fazer mais do que a própria vítima já poderia. Ainda assim é mutação sem token.

Correção: trocar a rota para `post` e passar `method: 'POST'` mais o
`X-CSRF-Token` no `fetch`. São umas quatro linhas.

### 2. O plugin sobrescreve `label_all`, que é uma chave do core

`config/locales/pt-BR.yml` do plugin define `label_all: "Todos"`. O core define
`label_all: todos`. Locales de plugin carregam depois e ganham, então a chave
passa a valer "Todos" **em toda a interface** — confirmado na instância.

São 7 arquivos do core que usam essa chave (busca, versões, campos personalizados,
repositórios, workflows). Aqui o estrago é só a maiúscula; em inglês vira
`all` → `All`. Correção: renomear para `dashboard_label_all` no plugin e na view.

### 3. Depende de uma CDN externa para os ícones

`index.html.erb` linha 5 carrega `bootstrap-icons` de `cdn.jsdelivr.net`. Sem
internet de saída, ou com a CDN fora do ar, os ícones de pessoa e ferramenta
somem — o resto da tela continua funcionando. O Redmine 7 não define CSP, então
o carregamento não é bloqueado, mas é uma chamada a terceiros a cada visita.

Correção: baixar o `.css` e a fonte para `assets/` do plugin e referenciar por
`stylesheet_link_tag ..., plugin: 'dashboard'`. Atenção ao achatamento de
subdiretório do Propshaft (correção 3 do `CLAUDE.md`).

### 4. Não pagina — carrega todas as tarefas visíveis

`get_issues` faz `Issue.visible.map` sem `limit` e sem `includes`, e a view
desenha um cartão por tarefa. Com poucas centenas é indiferente; com dezenas de
milhares, a tela carrega tudo em memória e monta tudo no DOM.

O N+1 é menos grave do que parece: o controller toca quatro associações por tarefa
(`status`, `project`, `author`, `assigned_to`) sem *preload*, mas o cache de
consultas do Rails deduplica as repetidas dentro da mesma requisição, então o custo
tende a (situações + projetos + pessoas distintas), não a 4 × tarefas.
Medição na instância atual: **15 consultas** — que hoje não tem tarefa nenhuma.

## Detalhes menores, sem ação necessária

- **Sem `requires_redmine`** no `init.rb`. Não há trava de versão: numa atualização
  futura do Redmine o plugin vai tentar carregar de qualquer jeito.
- **`script.js` linha 38** faz `document.querySelector('#main-menu').remove()` sem
  checar se o elemento existe. Na tela `/dashboard` ele existe (o Redmine 7 registra
  7 itens em `:application_menu`), então não quebra. Mas é frágil: em telas sem menu
  principal — `/my/page`, por exemplo — a mesma linha lançaria `TypeError` e abortaria
  o resto do `init()`.
- **`item.author.name(User::USER_FORMATS[:firstname_lastname])`** passa um Hash onde
  o Redmine espera um Símbolo. O `name_formatter` não encontra a chave e cai no
  formato padrão da instância. Não quebra; só ignora a intenção do autor.
- **As cores começam vazias.** Sem configurar, os cartões saem com a borda padrão
  do CSS e as etiquetas de projeto sem cor. O botão "Gerar as cores" resolve em um
  clique — é o primeiro passo depois de instalar.
- **Turbo.** O `motriz_2` carrega Turbo. A navegação do plugin usa `location.href`,
  que faz recarga completa e escapa do Turbo. Sem conflito observado.

## Manutenção do projeto

Praticamente parado. Dos 135 commits, **115 são de 2021**; 9 em 2022, 9 em 2023,
2 em 2025. O último é de abril de 2025 e é um merge de contribuição externa
(tradução). Não há release marcada para Redmine 6 ou 7 — a compatibilidade com o
7.0.0 é consequência de o plugin usar pouquíssima API, não de manutenção ativa.

Na prática isso significa: se algo quebrar numa atualização do Redmine, a correção
provavelmente terá de sair daqui. O tamanho ajuda — são 547 linhas legíveis.

## Como instalar

```bash
# no repositório
git clone --depth 1 https://github.com/akpaevj/dashboard.git \
  redmine-7/plugins/dashboard
rm -rf redmine-7/plugins/dashboard/.git redmine-7/plugins/dashboard/screenshots

# liberar no .gitignore, como já foi feito para motriz_2
echo '!/plugins/dashboard' >> redmine-7/.gitignore
```

Não precisa de passo de migração nem de `bundle install`. Depois do deploy, ir em
Administração → Plugins → Dashboard → Configurar e clicar em "Gerar as cores".

Para remover: apagar a pasta e reconstruir a imagem. Como não há tabela nem coluna
própria, a única sobra é a linha do `Setting` com as cores, inofensiva.
