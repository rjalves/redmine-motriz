# 04 — Mapa de seletores: os ganchos de usabilidade

Base: `reference/redmine7-layout-base.html.erb` (a árvore DOM de **toda** página) e
`reference/redmine7-core-application.css`.

## A árvore DOM que existe em toda página

```
body.<classes dinâmicas>
└─ #wrapper                        flex column
   ├─ .flyout-menu.js-flyout-menu  menu mobile (oculto no desktop)
   │    ├─ .flyout-menu__search
   │    ├─ .flyout-menu__avatar
   │    ├─ .js-project-menu        ← clone JS do #main-menu
   │    ├─ .js-general-menu        ← clone JS do #top-menu
   │    ├─ .js-sidebar             ← clone JS do #sidebar
   │    └─ .js-profile-menu        ← clone JS do #account
   ├─ nav#top-menu.top-menu        barra superior (fundo #234761)
   │    ├─ .general-menu > .top-menu__links
   │    └─ .profile-menu > #account.dropdown
   │         ├─ a.dropdown-trigger (avatar)
   │         └─ .dropdown-content > .user-info + .dropdown-divider + menu
   ├─ #header                      faixa do projeto (fundo #3A78A3)
   │    ├─ a.mobile-toggle-button.js-flyout-menu-toggle-button
   │    ├─ #quick-search > form + #project-jump
   │    ├─ h1                      título da página
   │    └─ #main-menu.tabs         abas do projeto (fundo --oc-indigo-0)
   │         └─ .tabs-buttons > button.tab-left / button.tab-right
   ├─ #main.collapsiblesidebar|.nosidebar     flex ROW-REVERSE
   │    ├─ #sidebar                ← vem depois no DOM, aparece à DIREITA
   │    │    ├─ #sidebar-switch-panel > a#sidebar-switch-button
   │    │    └─ #sidebar-wrapper
   │    └─ #content
   │         ├─ .flash (notice/error/warning)
   │         └─ (conteúdo da página)
   ├─ #footer
   ├─ #ajax-indicator
   ├─ #ajax-modal
   └─ #icon-copy-source
```

### Detalhe que pega gente desprevenida

```css
#main {flex-grow: 2; display: flex; flex-direction: row-reverse;}
```

`#sidebar` vem **antes** de `#content` no HTML mas é renderizado à **direita** por
causa do `row-reverse`. Para mover a sidebar para a esquerda basta:

```css
#main { flex-direction: row; }
#sidebar { border-inline-start: 0; border-inline-end: 1px solid var(--oc-gray-4); }
```

## `body_css_classes` — o gancho mais poderoso do tema

De `app/helpers/application_helper.rb`:

```ruby
def body_css_classes
  css = []
  if theme = Redmine::Themes.theme(Setting.ui_theme)
    css << 'theme-' + theme.name.tr(' ', '_')
  end
  css << 'project-' + @project.identifier if @project && @project.identifier.present?
  css << 'has-main-menu' if display_main_menu?(@project)
  css << 'controller-' + controller_name
  css << 'action-' + action_name
  if UserPreference::TEXTAREA_FONT_OPTIONS.include?(User.current.pref.textarea_font)
    css << "textarea-#{User.current.pref.textarea_font}"
  end
  css.join(' ')
end
```

O `<body>` carrega, em toda página:

| Classe | Significado | Uso típico num tema |
|---|---|---|
| `theme-<Nome>` | nome humanizado, espaços→`_` (ex.: `theme-Motriz_dark`) | escopar regras ao próprio tema |
| `project-<identifier>` | identificador do projeto atual | **cor/branding por projeto** |
| `has-main-menu` | há menu de projeto visível | ajustar altura do `#header` |
| `controller-<nome>` | ex.: `controller-issues`, `controller-projects` | layout por área |
| `action-<nome>` | ex.: `action-index`, `action-show`, `action-edit` | layout por tela |
| `textarea-<fonte>` | preferência de fonte do usuário | tipografia de editor |

**É isto que permite "mudar a usabilidade" sem plugin.** Exemplos reais:

```css
/* Lista de tarefas mais densa, só na listagem */
body.controller-issues.action-index table.list td { padding-block: 1px; }

/* Formulário de tarefa em duas colunas */
body.controller-issues.action-new  #content,
body.controller-issues.action-edit #content { max-inline-size: 1100px; }

/* Esconder a sidebar na página inicial do projeto */
body.controller-projects.action-show #sidebar { display: none; }

/* Branding por projeto */
body.project-infra #header { background: #2f5d3a; }
```

## Inventário de IDs estruturais do core

Extraídos de `redmine7-core-application.css` (só os de layout/chrome, sem cores hex):

**Layout:** `#wrapper` `#header` `#top-menu` `#main-menu` `#main` `#sidebar`
`#sidebar-wrapper` `#sidebar-switch-panel` `#sidebar-switch-button` `#content` `#footer`

**Navegação/busca:** `#account` `#quick-search` `#project-jump` `#search-form`
`#search-results` `#search-results-counts` `#admin-menu`

**Tarefas:** `#issue-form` `#issue_subject` `#issue_description_and_toolbar`
`#issue_done_ratio` `#issue_is_private_wrap` `#issue_tree` `#sticky-issue-header`
`#related-issues` `#relations` `#history` `#watchers` `#watchers_inputs`
`#issue_statuses_description`

**Consultas/filtros:** `#filters-table` `#query_form_content` `#query_form_with_buttons`
`#options` `#date-range` `#clear-query`

**Outras telas:** `#projects-index` `#my-page` `#activity` `#activity_scope_form`
`#roadmap` `#version-summary` `#news-list` `#document-list` `#time-report`
`#calendar`/`#months` `#login-form` `#my_account_form` `#user_form`
`#workflow_form` `#workflow_copy_form` `#bulk_edit_form`

**Feedback:** `#ajax-indicator` `#ajax-modal` `#errorExplanation` `#error` `#update`

## Componentes recorrentes (classes)

| Classe | Onde | Regra base relevante |
|---|---|---|
| `table.list` / `.table-list` | toda listagem | `th` = `--oc-gray-2` + borda 2px `--oc-gray-4`; `td` = borda-topo 1px |
| `tr.issue` | linha de tarefa | `text-align:center; white-space:nowrap` |
| `tr.issue.created-by-me td.author` | — | `font-weight: bold` |
| `tr.issue.assigned-to-me td.assigned_to` | — | `font-weight: bold` |
| `.odd` / `.even` | zebra das listas | dentro de `.box` o `even` vira branco |
| `.tabular` | **todos os formulários** | `label` com largura fixa à esquerda |
| `.tabular label.floating/.block/.inline/.error` | variantes de label | |
| `.contextual` | ações no topo direito | `float: inline-end; display: inline-flex` |
| `.box` | cartão/painel | agrupador visual padrão |
| `.splitcontent` + `.splitcontentleft/right/top` | layout 2 colunas | flex |
| `.journals` | histórico de comentários | |
| `.flash` `.flash.notice/.error/.warning` | mensagens | |
| `.tabs` | abas (também usado por `#main-menu`) | |
| `.drdn` `.drdn-content` `.drdn-items` | dropdowns | ver `redmine7-dropdown.css` |
| `.pagination` `.pages` | paginação | |
| `.wiki` | conteúdo renderizado de wiki/descrição | 74 regras — cuidado ao mexer |
| `.syntaxhl` | realce de código | 71 regras, hex fixo |
| `.avatar` | avatares (Gravatar) | |
| `.icon` `.icon-only` `.icon-svg` `.icon-actions` | ícones — ver [05](05-icones-svg.md) |
| `.progress` | barra de progresso | |
| `.cal` `.calbody` | calendário | |
| `.closed` | item fechado (tarefa/versão) | risco/opacidade |

## Convenção de escrita do core: propriedades lógicas

O CSS do Redmine 7 é escrito com **propriedades lógicas** (suporte nativo a RTL):

| Propriedade | Ocorrências |
|---|---:|
| `inline-size` | 119 |
| `margin-block` | 115 |
| `margin-inline` | 105 |
| `padding-inline` | 91 |
| `block-size` | 53 |
| `padding-block` | 47 |
| `inset-block` | 21 |
| `inset-inline` | 14 |
| `border-inline` | 12 |

**Escreva o tema no mesmo dialeto.** Misturar `left/right/width` com o core em
`inline-start/inline-end/inline-size` gera conflitos de especificidade difíceis de
achar e quebra o RTL (árabe/hebraico) que o Redmine suporta de fábrica.

| Físico | Lógico |
|---|---|
| `width` / `height` | `inline-size` / `block-size` |
| `padding-left` / `padding-right` | `padding-inline-start` / `padding-inline-end` |
| `margin-top` / `margin-bottom` | `margin-block-start` / `margin-block-end` |
| `left` / `right` | `inset-inline-start` / `inset-inline-end` |
| `border-left` | `border-inline-start` |
| `text-align: left` | `text-align: start` |
| `float: right` | `float: inline-end` |

Exceção legítima, e o próprio core faz: colunas numéricas usam `text-align: right`
de propósito (números continuam alinhados à direita mesmo em RTL).
