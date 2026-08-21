# 08 — Receitas prontas e armadilhas

## Boilerplate: tema para Redmine 6.0+/7.x

```
themes/motriz/
├─ stylesheets/application.css
├─ javascripts/theme.js
├─ images/icons.svg
├─ favicon/favicon.png
└─ src/                      ← ignorado pelo pipeline
```

`stylesheets/application.css`:

```css
/* ==========================================================================
   Motriz — tema Redmine
   Alvo: Redmine 7.x
   ========================================================================== */

/* 1. O core PRIMEIRO. Sem isto, página sem estilo. */
@import url(../../../stylesheets/application.css);

/* 2. Paleta — remapeia ~341 usos de var(--oc-*) no core de uma vez.
      Ao mudar --oc-X, mude também --oc-X-rgb se ele for usado. */
:root {
  --fonts-main: "Inter", system-ui, sans-serif;

  --oc-gray-0: #f6f7f9;
  --oc-gray-1: #eef0f4;
  --oc-gray-2: #e3e7ed;
  --oc-gray-4: #d0d6df;   /* bordas — 45 usos */
  --oc-gray-5: #98a1af;
  --oc-gray-6: #6f7889;   /* texto secundário — 35 usos */
  --oc-gray-7: #414958;   /* títulos — 20 usos */
  --oc-gray-9: #1a1e27;   /* texto principal */
  --oc-gray-9-rgb: 26, 30, 39;

  --oc-blue-7: #1f5fd0;   /* links */
  --oc-blue-9: #16408c;   /* ícones (stroke) */
  --oc-red-9:  #a01b32;   /* hover de ícone */

  --oc-indigo-0: #eef1fb; /* fundo do #main-menu */
  --oc-indigo-9: #232f66; /* item selecionado da sidebar */
}

/* 3. As DUAS cores que não são token (o core admite isso em comentário). */
nav.top-menu { background: #16233a; }
#header      { background: #203a63; }

/* 4. Ajustes estruturais — sempre em propriedades lógicas. */
#sidebar { background: var(--oc-gray-0); }
#footer  { background: var(--oc-white); }
```

`javascripts/theme.js`:

```js
(function () {
  'use strict';
  function onReady() {
    // roda com o DOM pronto; jQuery disponível como $
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }
})();
```

Instalar: copiar a pasta → **reiniciar o Redmine** → Administração →
Configurações → Exibição → Tema → "Motriz" → Salvar.

## Receitas

### Sidebar à esquerda

```css
#main { flex-direction: row; }              /* core usa row-reverse */
#sidebar {
  border-inline-start: 0;
  border-inline-end: 1px solid var(--oc-gray-4);
}
```

### Largura da sidebar (precisa cobrir a escada toda)

```css
@media screen and (min-width: 0px)    and (max-width: 1089px) { #sidebar { width: 26%;  } }
@media screen and (min-width: 1090px) and (max-width: 1279px) { #sidebar { width: 280px; } }
@media screen and (min-width: 1280px) and (max-width: 1599px) { #sidebar { width: 320px; } }
@media screen and (min-width: 1600px) and (max-width: 1919px) { #sidebar { width: 360px; } }
@media screen and (min-width: 1920px) and (max-width: 2559px) { #sidebar { width: 400px; } }
```

### Listagens mais densas, sem afetar o resto

```css
body.controller-issues.action-index table.list td { padding-block: 2px; }
body.controller-issues.action-index table.list th { padding: 3px; }
```

### Branding por projeto

```css
body.project-infraestrutura #header { background: #2f5d3a; }
body.project-comercial      #header { background: #6b3f8c; }
```

### Interface fluida abaixo de 900px no desktop

```css
body { min-inline-size: 0; }
```
(Teste as listagens largas depois — o mínimo existe por um motivo.)

### Tipografia com fonte própria

```css
/* themes/motriz/stylesheets/application.css */
@font-face {
  font-family: "Inter";
  src: url(../fonts/Inter-Variable.woff2) format("woff2");
  font-weight: 100 900;
  font-display: swap;
}
:root { --fonts-main: "Inter", system-ui, sans-serif; }
```
Coloque o `.woff2` em `themes/motriz/fonts/` — qualquer subdiretório vira asset path.

### Cabeçalho com logo

```css
#header {
  background: #203a63 url(../images/logo.png) no-repeat 12px center;
  background-size: auto 28px;
  padding-inline-start: 86px;
}
```

## Armadilhas

### 1. Esquecer o `@import` do core
Sem ele a página fica sem estilo nenhum. É a primeira linha, sempre.

### 1b. `responsive.css` carrega DEPOIS do tema e ganha nos empates
O layout faz:

```erb
stylesheet_link_tag 'jquery/...', 'tribute-...', 'application', 'dropdown', 'responsive'
```

O tema **ocupa o lugar de `application`** — então `dropdown.css` e `responsive.css`
vêm depois dele na cascata. Toda regra sua dentro de `@media (max-width: 899px)` que
empatar em especificidade com uma do `responsive.css` **perde**.

Sintoma clássico: o cabeçalho mobile volta a ficar azul (`#628db6`) mesmo com
`#header { background: … }` declarado no tema.

Solução: suba a especificidade nos overrides mobile.

```css
@media screen and (max-width: 899px) {
  body #header      { background-color: #024b40; }   /* 0,1,1 vence 0,1,0 */
  body .flyout-menu { background-color: #01342c; }
}
```

### 2. Tema não aparece no dropdown
Três causas, nesta ordem:
- Falta `stylesheets/application.css` **com esse nome exato** — `scan_themes` exige
- Pasta no lugar errado da versão (`themes/` no 6+/7, `public/themes/` no ≤5)
- **Não reiniciou** — a lista é memoizada em `@@installed_themes`

### 3. `custom.js` em vez de `theme.js`
`heads_for_theme` testa `javascripts.include?('theme')`. Qualquer outro nome nunca
é carregado.

### 4. JS rodando antes do DOM
`theme.js` entra no `<head>` como script clássico síncrono. Sem `DOMContentLoaded`,
`document.querySelector` devolve `null`.

### 5. Guardar referências dos menus no JS
`responsive.js` faz detach/append do `#top-menu`, `#main-menu`, `#sidebar` e
`#account` entre desktop e mobile — a cada `resize`. Use delegação de eventos.

### 6. Redefinir `--oc-X` e esquecer `--oc-X-rgb`
O core usa `rgba(var(--oc-gray-9-rgb), …)`. Sombras e overlays ficam com a cor velha.

### 7. Achar que redefinir tokens recolore tudo
`nav.top-menu` (`#234761`) e `#header` (`#3A78A3`) são hex fixo. São as duas barras
mais visíveis da tela.

### 8. Misturar propriedades físicas e lógicas
O core é escrito em lógicas (119 `inline-size`, 115 `margin-block`, …). Misturar
gera conflitos de especificidade e quebra o RTL.

### 9. Assumir `border-box`
Só existe dentro de `@media (max-width: 899px)`. No desktop o modelo é `content-box`.

### 10. Errar a forma do `@import` no Redmine 6/7
A forma relativa `../../../stylesheets/application.css` é do **Redmine 5**. No 6/7 ela
não resolve e a página sai sem estilo nenhum. Os temas nativos do Redmine 7 usam o
caminho lógico raiz:

```css
@import url(/application.css);
```

O Propshaft reescreve para `/assets/application-<hash>.css` no boot — nunca escreva o
digest à mão. Confira sempre contra `app/assets/themes/*/stylesheets/application.css`
da versão alvo.

### 11. Tema escuro só com tokens
Faltam: os 71 hexes de `.syntaxhl` (código ilegível), imagens/avatares com fundo
branco, Gantt, calendário e preview de anexos.

### 12. Vários arquivos em `favicon/`
`favicon` é `favicons.first` de um `Dir.glob` — a escolha vira dependente da ordem.
Coloque um arquivo só.

### 13. Colocar fontes de build em pasta servida
Sass, SVG originais e afins vão em `src/` — o único diretório que o `asset_paths`
exclui de propósito.

### 14. Plugins de terceiros com ícones quebrados no 7.0
Os ícones raster saíram no 7.0. Se houver plugin não migrado:
`@import url('/legacy-icons-compat.css');`

### 15. Achar que `--oc-yellow-0` é cor de aviso
Não é. No Redmine 7 ele pinta **o hover das linhas de tabela**, **o fundo do painel da
tarefa** (`div.issue`) e **o fundo do índice do wiki** (`div.wiki ul.toc`). É uma
superfície de destaque sutil, não um alerta.

Os avisos de verdade usam outros tokens:

```css
div.flash.warning, .conflict, .nodata, .warning {
  background-color: var(--oc-yellow-1);
  border-color: var(--oc-yellow-3);
  color: var(--oc-pink-9);
}
```

Sintoma de errar isso: o painel inteiro da tarefa fica creme alaranjado e o hover das
linhas puxa para laranja. Verificado rodando: com `--oc-yellow-0: #fff4e0` a tela de
detalhe ficou com cara de aviso permanente.

### 16. Seletor descendente vazando para a tabela aninhada do progresso
A barra de progresso é uma **`<table class="progress">` dentro de `td.done_ratio`**.
Qualquer regra escrita como `table.list td { … }` ou
`table.list tr.issue td:first-child { … }` alcança **também as células dela**.

Sintoma real observado: um marcador de prioridade em `td:first-child` apareceu como um
fio laranja de 3px dentro de cada barra de progresso.

Use combinador filho:

```css
table.list > tbody > tr > td { padding-block: 7px; }
table.list > tbody > tr.issue.priority-highest > td:first-child { box-shadow: inset 3px 0 0 …; }
```

O próprio core tem esse vazamento (`table.list td {padding-block: 3px}` atinge a barra),
então ele é comportamento herdado — mas o seu não precisa somar a ele.

### 17. Marcador de prioridade em `td.subject`
A ordem das colunas é configurável no Redmine e o assunto quase nunca é a primeira
coluna. Um `box-shadow: inset` em `td.subject` vira uma **régua vertical no meio da
tabela**, que se lê como borda de coluna, não como indicador de prioridade.
O marcador vai na primeira célula da linha.

### 18. Estilizar `.wiki` sem cuidado
São 74 regras no core cobrindo todo conteúdo renderizado (descrições, comentários,
páginas wiki). Mudanças amplas aí têm alcance muito maior do que parece.

## Checklist de validação

Antes de considerar o tema pronto, abrir e conferir:

- [ ] Login (`#login-form`) — deslogado
- [ ] Página inicial e Meus projetos (`#projects-index`, `#my-page`)
- [ ] Lista de tarefas com filtros abertos (`#filters-table`, `table.list`)
- [ ] Detalhe da tarefa: histórico, anexos, relacionadas (`.journals`, `#relations`)
- [ ] Nova/editar tarefa (`#issue-form`, `.tabular`)
- [ ] Wiki com código, tabela e imagem (`.wiki`, `.syntaxhl`)
- [ ] Gantt e calendário (`.cal`)
- [ ] Atividade e Repositório
- [ ] Administração (`#admin-menu`) e todas as abas de Configurações
- [ ] Mensagens `.flash` notice / warning / error
- [ ] Dropdown do avatar (`#account .dropdown-content`)
- [ ] **< 900px**: flyout abre, contém projeto/geral/sidebar/perfil
- [ ] **< 600px**: paginação e filtros
- [ ] Sidebar recolhida (`#sidebar-switch-button`) e reaberta
- [ ] Contraste AA nos textos secundários (`--oc-gray-5`/`-6` sobre branco)
- [ ] Favicon trocado
- [ ] Se houver plugins: telas de cada plugin
