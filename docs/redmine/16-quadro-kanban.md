# Quadro Kanban — o que existe, onde mora e por que

## Resumo

O Redmine da Motriz tem um quadro Kanban desde o fork do ASAP Theme. Ele estava
**escondido**: atrás de uma preferência por usuário desligada por padrão, e
alcançável só por um alternador dentro da lista de tarefas.

Este documento registra o que foi encontrado, o que mudou e por quê.

## O quadro nunca precisou ser construído

Ao procurar o padrão visual do `motriz_2` para escrever um Kanban novo,
apareceu que o `motriz_2` **já tinha um**, e mais capaz que o do
[`akpaevj/dashboard`](15-dashboard-plugin.md):

| Recurso | `akpaevj/dashboard` | quadro do `motriz_2` |
|---|---|---|
| Colunas | situação | situação **ou versão** |
| Raias horizontais | não | sim, por qualquer agrupamento da consulta |
| Filtros | seletor de projeto | `IssueQuery` inteiro + consultas salvas |
| Ordem dos cartões | não persiste | gravada em `board_card_positions` |
| Reversão se o fluxo recusa | não | sim, rollback otimista |
| Cartão | id, assunto, projeto, responsável | + tracker colorido, prioridade, avatar, checklist, data-alvo |
| Mudança de situação | **GET sem CSRF** | PATCH com token |

Construir outro duplicaria cerca de mil linhas e colocaria dois quadros
concorrentes na mesma interface.

### Onde cada peça mora

Tudo em `redmine-7/plugins/motriz_2/`:

| Peça | Caminho |
|---|---|
| Colunas, raias | `app/views/issues/_board.html.erb` |
| Cartão | `app/views/issues/_board_card.html.erb` |
| Arrastar e soltar | `assets/javascripts/controllers/board_controller.js` |
| Gravar situação e ordem | `app/controllers/board_positions_controller.rb` |
| Modelo da ordem | `app/models/board_card_position.rb` + migração |
| Opções de coluna na consulta | `lib/redmine_asap_theme/issue_query_patch.rb` |
| Seletor de colunas no filtro | `app/overrides/query_form_board_options.rb` |
| Estilo `.board-*` | `assets/src/issue.css` → `assets/stylesheets/application.css` |

O drag-and-drop é HTML5 nativo, **não usa SortableJS** — apesar de o plugin
trazer uma cópia do SortableJS, que é usada só pelo checklist.

## O plugin `motriz_kanban`

Em `plugins/motriz_kanban/` (raiz do repositório, junto de `redmine_google_sso` e
`redmine_mcp_server` — `redmine-7/plugins/` é reservado ao fork do tema).

São 4 arquivos: `init.rb`, um controller, uma view e as rotas. **Nenhum quadro
próprio, nenhum CSS, nenhuma migração.** Ele só acrescenta as duas portas de
entrada que faltavam: `/quadro` e `/projects/:id/quadro`.

### Três armadilhas do Redmine que este plugin atravessou

**1. `:top_menu` não existe neste tema.** O layout do `motriz_2` substitui o
`base.html.erb` do core e nunca chama `render_menu :top_menu` — só
`:tools_menu`, `:admin_menu` e `render_main_menu`. Um item registrado no
`:top_menu` fica **invisível**, sem erro. É por isso que o próprio `motriz_2`
pendura "Minha página" no `:tools_menu`. O destino certo para um item global é
`:application_menu`, que é o que o `render_main_menu` resolve sem projeto.

**2. Item de menu de projeto exige `:permission` explícita.** Sem ela,
`MenuItem#allowed?` (`lib/redmine/menu_manager.rb`) cai no ramo que infere a
permissão do par controller/action. Como `motriz_kanban/index` não está
registrado em permissão nenhuma, `Project#allows_to?` devolve `false` — e essa
checagem vem **antes** do `return true if admin?` em `User#allowed_to?`. A aba
ficaria escondida inclusive para o administrador.

**3. `find_optional_project` do core não serve.** Ele termina em
`authorize_global`, que resolve a permissão pelo mesmo par controller/action.
Resultado sem permissão registrada: 403 para todos. O controller autoriza à mão
contra `:view_issues`.

> Regra geral: **um controller de plugin sem `permission` registrada no `init.rb`
> não passa por `authorize`/`authorize_global`, e seus itens de menu com URL em
> Hash somem.** Ou registre uma permissão, ou autorize à mão contra uma
> permissão que já exista.

Aqui a escolha foi **não criar permissão nova**: o quadro é outra forma de olhar
as mesmas tarefas, então herda `:view_issues` e fica amarrado ao módulo
`issue_tracking`. Uma permissão nova nasceria desmarcada em todos os papéis e
ninguém veria nada até um administrador marcar uma a uma.

## Defeitos corrigidos no `motriz_2`

Todos encontrados verificando o comportamento real contra o servidor.

### 1. `label_board` sequestrava uma chave do core

`label_board` é chave do core e significa **"Forum"**. O `motriz_2` a
sobrescrevia em `en.yml` (`Columns`) e `fr.yml` (`Colonnes`). Consequências:

- em português o botão do alternador mostrava **"Fórum"** (o `pt-BR.yml` do
  plugin não sobrescrevia, então valia o core);
- em inglês, **quatro telas do core** passaram a dizer "Columns" onde queriam
  dizer "Forum": `messages/_form`, `projects/settings/_boards`, `boards/index`,
  `boards/edit`.

Corrigido com chaves próprias `label_motriz_quadro` e `label_motriz_tabela`.

> Lição: **nunca redefinir uma chave do core em locale de plugin.** Locales de
> plugin carregam depois e ganham silenciosamente, em toda a interface.

### 2. As colunas eram só as situações que já tinham tarefa

O padrão vinha de `board_issues.map(&:status_id).uniq`. Se todas as tarefas
estivessem em "Nova", existia **uma coluna só** — e não havia para onde arrastar.
O quadro só ficava utilizável depois que alguém já tivesse espalhado as tarefas
por outro caminho.

O padrão agora é `IssueStatus.sorted`, o fluxo inteiro. As colunas são o processo
de trabalho, não a distribuição de hoje. Quem quiser menos escolhe em "Colunas"
no formulário de filtros.

### 3. O quadro sumia quando não havia tarefa

`issues/index.html.erb` cortava com `<p class="nodata">` **antes** de decidir
entre tabela e quadro. Num Kanban as colunas vazias é que mostram o fluxo. O
corte agora vale só para a tabela.

### 4. A consulta não tinha teto

`_board.html.erb` chamava `query.issues(...)` sem `limit`. A lista de tarefas
nunca sofreu disso porque pagina; o quadro carregaria **todas** as tarefas
visíveis e montaria um cartão para cada uma no DOM. Teto de 500 cartões, com
aviso de truncamento (`warning_board_truncated`).

### 5. Colunas por versão davam tela vazia na visão global

`project.versions` com `project` nulo. Agora cai nas versões usadas pelas tarefas
carregadas — na parcial e no seletor do formulário.

### 6. pt-BR do quadro inexistia

Treze chaves traduzidas, mais o rótulo "Table" que estava fixo no HTML sem passar
por `l()`. **O restante do `en.yml` do tema (mais de cem chaves) continua sem
tradução pt-BR** — dívida conhecida, fora do escopo desta entrega.

## Ativação

A preferência `board_view_enabled` passou de "desligada por padrão" para
**"ligada por padrão"**: a checagem virou `!= '0'` em `issues/index.html.erb` e
em `user_settings/_appearance.html.erb`.

Quem desligar de propósito grava `'0'` — o `hidden_field` da tela de Aparência
garante isso — e continua sem ver.

Estado do servidor quando a mudança foi feita: dos 3 usuários ativos, só `admin`
tinha a chave gravada, com valor `'1'`. **Ninguém tinha `'0'`**, então ninguém
ficou de fora por acidente. Numa instância com mais gente vale conferir antes:

```sql
SELECT COUNT(*) FROM user_preferences WHERE others LIKE '%board_view_enabled%';
```

Se houver `'0'` gravado por quem só queria trocar o tema, a virada não os alcança
e é preciso limpar a chave.

## Limitações conhecidas

- **Na visão global, reordenar cartões dentro de uma coluna não persiste.**
  `board_card_positions` é indexada por projeto; sem projeto o
  `board_controller.js` nem tenta gravar. Arrastar **entre** colunas funciona,
  porque isso muda a situação da tarefa.
- **Salvar uma consulta a partir do quadro leva de volta para a lista.** É o
  `QueriesController#create` do core que redireciona.
- **`label_redmine_environment` está duplicada** em `en.yml` e `fr.yml` do
  `motriz_2` — defeito herdado do upstream, sem efeito prático (o YAML resolve
  pelo último).

## Verificação feita

Contêiner descartável a partir da imagem de produção, mesma rede, banco de
produção, entrypoint substituído — o contêiner no ar nunca foi tocado.

- Plugin registrado, dependência `motriz_2` resolvida, duas rotas desenhadas.
- Itens em `:application_menu` e `:project_menu`; confirmado que **não** foi para
  o `:top_menu`.
- `/quadro` e `/projects/x/quadro` como administrador: HTTP 200, **6 colunas de 6
  situações**, controller Stimulus conectado.
- Anônimo: 302 para o login nas duas rotas, igual ao `/issues` do core.
- `label_board` de volta a "Fórum" (pt-BR) e "Forum" (en).
- Com 3 tarefas criadas **dentro de uma transação revertida**: 3 cartões,
  assunto, etiqueta do tracker, barra de progresso e etiqueta de projeto na
  visão global. `Issue.count` voltou a 0 depois do rollback.
