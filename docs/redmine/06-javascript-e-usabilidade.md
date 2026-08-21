# 06 — JavaScript do tema: onde está a fronteira

## Como o `theme.js` entra

Ordem no `<head>` (de `base.html.erb`):

```erb
<%= stylesheet_link_tag ... 'application', 'dropdown', 'responsive' %>
<%= javascript_importmap_tags %>   <!-- Stimulus / Hotwired -->
<%= javascript_heads %>            <!-- jQuery, rails-ujs, tribute, application-legacy, responsive -->
<%= heads_for_theme %>             <!-- SEU theme.js -->
```

Consequências:

1. **jQuery já está disponível** quando seu `theme.js` roda (`$` global,
   jQuery 3.7.1 + jQuery UI 1.13.3).
2. **O DOM ainda NÃO existe** — o script está no `<head>` e é síncrono clássico
   (`javascript_include_tag`, não módulo, sem `defer`).
   Tudo precisa ir para dentro de um handler de ready.
3. Só o nome `theme.js` é carregado (`javascripts.include?('theme')`).

### Esqueleto obrigatório

```js
// themes/<seu_tema>/javascripts/theme.js
(function () {
  'use strict';

  function onReady() {
    // seu código aqui — o DOM existe
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }
})();
```

Ou, já que jQuery está carregado: `$(function () { ... });`

## Stack JS disponível

| Biblioteca | Como acessar |
|---|---|
| jQuery 3.7.1 + jQuery UI 1.13.3 | `$` global |
| rails-ujs | global |
| Stimulus (Hotwired) | via importmap (`@hotwired/stimulus`) |
| tribute 5.1.3 | autocomplete de menções |
| tablesort | usado pelo `tablesort_controller` |
| chart.js 4.5.1 | `preload: false` — carregado sob demanda |
| turndown 7.2.0 | HTML→Markdown |

Controllers Stimulus do core (`app/javascript/controllers/`):
`api_key_copy` `clipboard` `custom_field_default_value` `dropdown`
`list_autofill` `quote_reply` `selection_indent` `sticky_issue_header`
`table_paste` `tablesort` + pastas `gantt/` `reports/` `repositories/`

Você **pode** anexar comportamento a esses elementos, mas não substituir os
controllers pelo tema (o importmap é do app, não do tema).

## Funções globais do core que você pode reaproveitar

De `application-legacy.js` e `responsive.js`:

| Função | O que faz |
|---|---|
| `openFlyout()` / `closeFlyout()` | abre/fecha o menu mobile |
| `isMobile()` | `true` se o botão de flyout está visível — **é assim que o core define "mobile"** |
| `setupFlyout()` | inicializa o menu mobile |
| `warnLeavingUnsaved(msg)` | aviso de saída com alterações não salvas |
| `moveTabLeft(el)` / `moveTabRight(el)` | rolagem das abas do `#main-menu` |
| `$('#main.collapsiblesidebar').collapsibleSidebar()` | plugin jQuery da sidebar retrátil |

Detalhe útil: `isMobile()` não usa `window.innerWidth` — testa a visibilidade do
`.js-flyout-menu-toggle-button`. Se o seu tema mudar o breakpoint no CSS, o JS do
core acompanha sozinho. **Não reimplemente essa checagem com media query em JS.**

## O que o `theme.js` PODE fazer

- Reordenar/mover elementos no DOM (ex.: tirar ação da `.contextual` e colocar no topo)
- Adicionar classes ao `<body>` ou a componentes para novos estados
- Agrupar campos de formulário em abas ou seções colapsáveis
- Adicionar atalhos de teclado
- Persistir preferências de UI em `localStorage` (sidebar recolhida, densidade)
- Injetar elementos puramente visuais (badges, contadores derivados do DOM)
- Melhorar tabelas (fixar cabeçalho, colunas congeladas)
- Adicionar comportamento a elementos existentes via delegação de eventos

## O que o `theme.js` NÃO deve fazer

- **Reescrever formulários que o Rails envia.** Mexer em `name`, adicionar/remover
  inputs ou reordenar campos com `name` quebra o `params` no controller e o
  `authenticity_token`.
- **Depender de estrutura interna de views.** As views ERB mudam entre versões
  do Redmine; seletores muito específicos quebram no upgrade.
- **Duplicar o que CSS resolve.** Esconder via JS causa flash de conteúdo (FOUC).
- **Trocar textos/traduções.** Isso é i18n — faça no Redmine, não no tema.
- **Adicionar itens de menu.** `top_menu`/`main_menu` são registrados no Ruby;
  injetar `<li>` via JS produz item que some em navegação AJAX e não respeita permissão.

## A fronteira: tema vs plugin

| Necessidade | Tema resolve? |
|---|---|
| Cor, tipografia, espaçamento, densidade | ✅ CSS |
| Esconder/reposicionar elementos | ✅ CSS |
| Layout por tela (`controller-*`/`action-*`) | ✅ CSS ([04](04-mapa-de-seletores.md)) |
| Branding por projeto (`project-*`) | ✅ CSS |
| Trocar ícones | ✅ `images/icons.svg` ([05](05-icones-svg.md)) |
| Reorganizar DOM existente | ⚠️ `theme.js` — frágil a upgrade |
| Novo campo / nova coluna / novo filtro | ❌ plugin |
| Novo item de menu | ❌ plugin |
| Nova permissão, rota, tela | ❌ plugin |
| Mudar texto/tradução | ❌ i18n ou plugin |
| Alterar a view ERB de verdade | ❌ plugin (view hooks) |

Se o escopo do redesenho exigir mais de umas poucas manipulações de DOM, o sinal é
claro: **tema para o visual + plugin fino para estrutura.** O Redmine expõe
*view hooks* (`call_hook :view_layouts_base_html_head`,
`:view_layouts_base_body_top`, `:view_layouts_base_body_bottom`,
`:view_layouts_base_content`, `:view_layouts_base_sidebar`) — todos visíveis em
`reference/redmine7-layout-base.html.erb`.

## Nota de Propshaft (Redmine 6.0+)

Caminhos de imagem dentro do JS precisam de `RAILS_ASSET_URL` para receber o digest.
A wiki documenta:

```js
// você escreve
this.img = RAILS_ASSET_URL("/icons/trash.svg")

// o Propshaft entrega
this.img = "/assets/icons/trash-54g9cbef.svg"
```
