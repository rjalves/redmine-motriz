# 07 — Responsivo, sidebar adaptativa e RTL

Base: `reference/redmine7-responsive.css` (909 linhas) e o core.

## Os dois breakpoints reais

O Redmine tem **apenas dois** breakpoints principais — iguais no 5.1 e no 7.0:

```css
@media screen and (max-width: 899px) { /* modo mobile completo */ }
@media all    and (max-width: 599px) { /* ajustes finos de telefone */ }
```

### `max-width: 899px` — a virada de modo

É aqui que a interface troca de paradigma. O que acontece:

| Efeito | Detalhe |
|---|---|
| `box-sizing: border-box` global | aplicado em `*`, `*:before`, `*:after` **só no mobile** |
| `body { min-inline-size: 0 }` | anula o `min-inline-size: 900px` do desktop |
| Fonte base cai para `0.875rem` (14px) | em `body, input, select, textarea, button` |
| `#top-menu` e `#main-menu` são **escondidos** | seu conteúdo é movido para o flyout via JS |
| `#sidebar` e `#sidebar-switch-panel` escondidos | idem — vão para o flyout |
| `.flyout-menu` e o botão hambúrguer ficam visíveis | acima de 900px estão ocultos |

**Pegadinha importante:** o `box-sizing: border-box` **não vale no desktop**. Se você
escrever CSS assumindo border-box, seus paddings vão medir diferente acima e abaixo
de 900px. Ou declare `box-sizing` você mesmo no tema para os dois modos, ou trabalhe
com o modelo `content-box` no desktop.

### `max-width: 599px` — ajustes de telefone

Escopo pequeno e específico: paginação reduzida a anterior/atual/próximo, links
prev/next da tarefa centralizados, `#login-form` em 100%, filtros em coluna cheia.

## O menu flyout mobile

Marcação (já presente em toda página, ver [04](04-mapa-de-seletores.md)):

```
.flyout-menu.js-flyout-menu
├─ .flyout-menu__search
├─ .flyout-menu__avatar
├─ .js-project-menu     ← recebe o #main-menu clonado
├─ .js-general-menu     ← recebe o #top-menu clonado
├─ .js-sidebar          ← recebe o #sidebar clonado
└─ .js-profile-menu     ← recebe o #account clonado
```

O `responsive.js` **move o DOM de verdade** (detach/append) entre desktop e mobile,
e refaz isso a cada `resize`. Duas consequências práticas:

1. **Não guarde referências de elemento** desses menus no seu `theme.js` — elas
   ficam obsoletas após um resize. Use **delegação de evento** a partir de
   `document` ou `#wrapper`.
2. Regras CSS que dependem de ancestral (`#sidebar .minha-classe`) **param de valer**
   no mobile, porque o elemento passa a viver dentro de `.flyout-menu`. Estilize por
   classe própria, não pelo container.

`isMobile()` retorna `$('.js-flyout-menu-toggle-button').is(":visible")` — a
definição de "mobile" no JS é **a visibilidade do botão**, controlada pelo CSS. Se
você mudar o breakpoint no tema, o JS acompanha automaticamente.

## Largura da sidebar: escada de media queries

O core define a sidebar em degraus (note: aqui usa `width` físico, não lógico):

```css
@media screen and (min-width: 0px)    and (max-width: 1089px) { #sidebar { width: 22%;  } }
@media screen and (min-width: 1090px) and (max-width: 1279px) { #sidebar { width: 240px; } }
@media screen and (min-width: 1280px) and (max-width: 1599px) { #sidebar { width: 280px; } }
@media screen and (min-width: 1600px) and (max-width: 1919px) { #sidebar { width: 320px; } }
@media screen and (min-width: 1920px) and (max-width: 2559px) { #sidebar { width: 360px; } }
```

Para mudar a largura da sidebar **é preciso sobrescrever toda a escada** — uma regra
única de `#sidebar { inline-size: ... }` perde para as media queries por
especificidade/ordem em várias faixas. Sobrescreva bloco a bloco.

## `min-inline-size: 900px` no `body`

```css
body { ... min-inline-size: 900px; }
```

O Redmine desktop **não é fluido abaixo de 900px** — ele força scroll horizontal e
só solta esse mínimo dentro do breakpoint mobile. Se o seu tema pretende ser fluido
em janelas estreitas no desktop, é este valor que precisa cair.

## RTL

O Redmine suporta RTL nativamente. O layout declara:

```erb
<html lang="<%= current_language %>" dir="<%= l(:direction) %>">
```

No Redmine 7 **não existe mais `rtl.css` separado** (existia no 5.1). O suporte vem
de escrever o CSS com propriedades lógicas ([04](04-mapa-de-seletores.md)), mais
alguns ajustes pontuais com `[dir="rtl"]` — sobretudo backgrounds com posição
explícita, que propriedade lógica não cobre:

```css
[dir="rtl"] tr.idnt :is(td.subject, td.name) {
  background: url(/chevron-left-idnt.svg) no-repeat right 2px center;
}
```

Regra para o tema: **use propriedades lógicas por padrão**; só recorra a
`[dir="rtl"]` para `background-position`, `transform` e SVGs direcionais.

Para ícones que devem espelhar, o core já oferece a classe `icon-rtl`
(parâmetro `rtl: true` no helper `sprite_icon`).

## Alvos de toque

Em telas de toque o Redmine tem alvos pequenos por herança (ícones de 18px, links
de tabela). Se o redesenho contempla uso em tablet/celular, aumente área clicável
dentro do breakpoint de 899px:

```css
@media screen and (max-width: 899px) {
  table.list td a,
  .contextual a.icon,
  #sidebar a { min-block-size: 44px; display: inline-flex; align-items: center; }
}
```
