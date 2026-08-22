# 12 — AdminLTE 4 como base do tema: diagnóstico

Pergunta avaliada: **o template AdminLTE v4 pode servir de base para o tema do Redmine?**

Fontes: <https://adminlte.io/themes/v4/docs/introduction.html> e as páginas de
*Layout*, *Customization*, *Getting Started* e *Main Sidebar* da mesma documentação,
mais medição direta sobre `admin-lte@4.8.4` baixado do jsDelivr (21/08/2026).

## Veredito

**Não como base. Sim como referência visual.**

O AdminLTE é um *template de marcação* — a própria documentação diz: "AdminLTE is a
**template**, not a component library". Todo o CSS dele é escrito contra classes
(`.app-sidebar`, `.nav-treeview`, `.card`) que **não existem no HTML do Redmine** e
que um tema **não pode criar**, porque tema não altera view ([01](01-arquitetura-de-temas.md),
[06](06-javascript-e-usabilidade.md)).

Medido: das **2.467** classes que o `adminlte.min.css` estiliza, apenas **11**
aparecem no CSS do Redmine 7 — e as 11 são colisões nocivas, não aproveitamento.
Na prática, **99,6% do arquivo não casaria com nada** na tela.

## O que o AdminLTE 4 é, em números

| Fato | Valor | Como foi apurado |
|---|---|---|
| Versão atual | `admin-lte@4.8.4` | doc de instalação |
| Licença | MIT | `dist/css/adminlte.min.css`, cabeçalho |
| Base | Bootstrap 5.3.8 (mín. 5.3.0) | doc de instalação |
| Linguagem do JS | TypeScript compilado, **sem jQuery** | doc de instalação |
| Ícones | Bootstrap Icons 1.13.1 (fonte de ícones) | doc de instalação |
| Dependências de runtime | Popper 2.11.8, OverlayScrollbars 2.11.0, Bootstrap JS | doc *Getting Started* |
| `dist/css/adminlte.min.css` | **311.728 bytes** | download |
| — dos quais Bootstrap | **232.111 bytes** (74,5%) | `bootstrap@5.3.8` baixado e comparado |
| — específico do AdminLTE | ≈ **79.617 bytes** | diferença |
| `dist/js/adminlte.min.js` | 27.750 bytes (+ build ESM) | download |
| `!important` no CSS | **2.021 ocorrências** | `grep -c` |
| Build RTL | **arquivo separado** (`adminlte.rtl.min.css`) | listagem do pacote |
| Node mínimo p/ compilar | 18 LTS (recomendado 22) | doc de instalação |
| IE11 | não suportado | doc *Browser Support* |

**O Bootstrap vem embutido no `adminlte.min.css`** — não é carregado à parte, como
alguma leitura apressada da página de *Getting Started* sugere. Verificado: o arquivo
abre com `:root,[data-bs-theme=light]{--bs-blue:#0d6efd;…}`, define 461 variáveis
`--bs-*`, contém `.container-fluid`, `.btn-primary`, `.form-control` e o **Reboot
completo** (`*,::after,::before{box-sizing:border-box}` e `body{margin:0;…}`).
Só 40 variáveis são `--lte-*` (sidebar, busca, callout, chat, ribbon, card variant).

## O teste decisivo: colisão de seletores

Interseção entre `adminlte.min.css` (2.467 classes) e
`reference/redmine7-core-application.css` (551 classes):

```
.badge  .breadcrumb  .css  .description  .disabled  .modal
.pagination  .progress  .time  .tooltip  .visible
```

**IDs em comum: nenhum.** E o layout do Redmine é inteiramente por ID
(`#wrapper`, `#top-menu`, `#header`, `#main-menu`, `#main`, `#sidebar`, `#content`,
`#footer` — ver [04](04-mapa-de-seletores.md)). O AdminLTE não estiliza um único ID.

Ou seja, a sobreposição não é "quase nada" por acaso: são **dois sistemas de
nomenclatura disjuntos**. E o pouco que se toca, se atropela:

| Classe | No Redmine | No AdminLTE/Bootstrap | Resultado |
|---|---|---|---|
| `.progress` | `<table class="progress">` — a **barra de progresso** de cada tarefa, com `td.closed/.done/.todo` | `.progress{display:flex;overflow:hidden;height:1rem;background:…}` | barra de progresso destruída em toda listagem |
| `.pagination` | `span.pagination > ul.pages` | `.pagination{display:flex;padding-left:0;list-style:none}` + 20 variáveis | paginação desalinhada |
| `.badge` | `.badge-private`, `.badge-count` | `.badge{display:inline-block;padding:…;color:#fff}` | badges recoloridos e redimensionados |
| `.disabled`, `.description`, `.time`, `.visible` | usos próprios do core | utilitários Bootstrap | conflitos difusos |

E antes de qualquer colisão de classe vem o **Reboot**, que reescreve `body`, `table`,
`a`, `h1..h6`, `input`, `button`, `label` e aplica `box-sizing:border-box` global.
O Redmine desktop trabalha em `content-box` — border-box só existe dentro do
breakpoint de 899px ([07](07-responsivo-e-rtl.md), armadilha 9 em
[08](08-receitas-e-armadilhas.md)). Carregar o Reboot por cima significa **remedir
todo padding do core**.

## As quatro rotas possíveis

### A) Carregar `adminlte.min.css` depois do core do Redmine — inviável

`@import url(/application.css);` seguido de `@import url(../stylesheets/adminlte.min.css);`
funciona sintaticamente. O resultado é: 311 KB de peso morto (99,6% sem alvo),
Reboot desmontando o core, 2.021 `!important` vencendo qualquer ajuste posterior do
tema e as colisões da tabela acima. Nenhum ganho visual — a sidebar do Redmine não
vira a sidebar do AdminLTE só porque o CSS dela foi carregado.

### B) Reescrever o DOM no `theme.js` para a marcação do AdminLTE — inviável

Seria preciso montar, em JavaScript, `.app-wrapper > .app-header + .app-sidebar >
.sidebar-wrapper > ul.sidebar-menu > li.nav-item > a.nav-link` a cada página. Colide
frontalmente com quatro fatos já documentados:

1. `theme.js` roda no `<head>`, **antes do DOM existir** ([06](06-javascript-e-usabilidade.md)).
   Reconstruir layout depois do `DOMContentLoaded` produz FOUC em toda navegação.
2. O `responsive.js` do core faz **detach/append do `#top-menu`, `#main-menu`,
   `#sidebar` e `#account` a cada `resize`** ([07](07-responsivo-e-rtl.md)) — ele
   desmontaria a árvore recriada.
3. Os plugins JS do AdminLTE (Treeview, PushMenu, Layout) dependem de **Bootstrap JS
   + Popper + OverlayScrollbars**, nenhum presente no Redmine, e são **ESM**. O
   importmap é do app, não do tema.
4. Mexer em formulários que o Rails envia quebra `params` e `authenticity_token`
   ([06](06-javascript-e-usabilidade.md)).

### C) Plugin que sobrescreve as views para a marcação AdminLTE — caro e frágil

Tecnicamente possível: um plugin do Redmine pode sobrepor `app/views/layouts/base.html.erb`.
É o caminho que a prática histórica confirma — os projetos "Bootstrap para Redmine"
existentes são **plugins que sobrescrevem views**, não temas
([redmine_bootstrap](https://github.com/reubenmallaby/redmine_bootstrap):
"Plugin to override some Redmine views using the Bootstrap CSS scheme").

Custo real: assumir a manutenção da view mais central do Redmine a cada upgrade,
mais as views de cada tela que se quiser "bootstrapizar", mais o conflito de Reboot
com o `application.css` do core, que continua carregado. Sai da definição de "plugin
fino" acordada em [09](09-plugin-fino.md) por uma ordem de grandeza.

> Existe implementação real dessa rota, com Tailwind no lugar do Bootstrap:
> o `redmine_asap_theme`. Foi medido em [13](13-asap-theme-como-base.md) — e o custo
> concreto está lá: 69 views sobrescritas, 20 patches Ruby e 6 migrations.

### D) AdminLTE como referência de design, reimplementada nos seletores do Redmine — é o caminho

Ler o AdminLTE como **decisão de design** e escrever o resultado em CSS que fala a
língua do Redmine. É também o que o precedente mais respeitado da comunidade fez:
o **PurpleMine2** "usa normalize.css e aproveita partes do Bootstrap como mixins e
estrutura" — nível de código-fonte, nunca o `dist` inteiro.

## O que vale a pena aproveitar do AdminLTE

| Ideia | Como entra no tema Motriz |
|---|---|
| Sidebar escura de largura fixa com item ativo destacado | `#sidebar` já está à esquerda (`#main{flex-direction:row}`); trata-se de recolorir e refazer a escada de larguras ([07](07-responsivo-e-rtl.md)) |
| Conteúdo em cartões sobre fundo neutro | já implementado na seção 8 do tema, via `.box` |
| Escala de espaçamento e densidade de dashboard administrativo | ajuste de `padding-block` por tela com `controller-*`/`action-*` ([04](04-mapa-de-seletores.md)) |
| `--lte-sidebar-width` como token único de largura | criar `--motriz-sidebar-width` e usá-lo em toda a escada de media queries |
| Estratégia de *color mode* (`[data-bs-theme=dark]`) | o Redmine não tem modo escuro; o padrão de atributo no `<html>` é replicável, com as ressalvas de [03](03-tokens-e-cores.md) e armadilha 11 de [08](08-receitas-e-armadilhas.md) |
| `dist/css/adminlte-colors.css` (58 KB) como banco de cores | dispensável — o Redmine já traz Open Color, e a paleta é a Motriz ([11](11-mapeamento-de-tokens.md)) |

## O que o AdminLTE **não** resolveria e o tema atual já resolve

- **Recoloração global barata.** 341 usos de `var(--oc-*)` recolorem com ~40 linhas
  de `:root` ([03](03-tokens-e-cores.md)). O AdminLTE não alcança nenhum deles.
- **Ícones.** O Redmine 7 usa sprite SVG com ids `icon--<nome>` e override por ícone
  pelo próprio motor de temas ([05](05-icones-svg.md)). O AdminLTE usa Bootstrap
  Icons como **fonte de ícone** — outro sistema, sem ponte.
- **RTL.** O core do Redmine 7 é escrito em propriedades lógicas, num arquivo só, e
  não tem mais `rtl.css` ([07](07-responsivo-e-rtl.md)). O AdminLTE resolve RTL com
  **um segundo arquivo compilado** (`adminlte.rtl.min.css`), modelo que o motor de
  temas não sabe alternar — ele serve um `application.css` e pronto.
- **Identidade Motriz.** O brandbook restringe fundo do logo a verde escuro ou branco
  e proíbe cores fora da paleta ([10](10-identidade-motriz.md)). Adotar o vocabulário
  visual do Bootstrap traria `#0d6efd` e a escala cinza dele como padrão a combater.
- **Peso.** O tema Motriz hoje tem **31,6 KB** contra 84,4 KB do core. A rota (A)
  somaria 311 KB — quase 4× o próprio Redmine — para não pintar quase nada.

## Recomendação

Manter a arquitetura atual — tema CSS sobre os tokens do Redmine — e usar o AdminLTE
apenas como **repertório visual de painel administrativo**: densidade, hierarquia de
sidebar, tratamento de cartões, comportamento do item ativo. Nada de `dist/`.

Se em algum momento se quiser o vocabulário Bootstrap de verdade dentro do Redmine, a
única rota honesta é a (C) — plugin que assume a manutenção das views — e essa decisão
precisa ser tomada com o custo de upgrade explícito na mesa, não como subproduto de
uma escolha de tema.

## Fontes

- [AdminLTE v4 — Introduction](https://adminlte.io/themes/v4/docs/introduction.html)
- [AdminLTE v4 — Layout](https://adminlte.io/themes/v4/docs/layout.html)
- [AdminLTE v4 — Customization](https://adminlte.io/themes/v4/docs/customization.html)
- [AdminLTE v4 — Getting Started](https://adminlte.io/themes/v4/docs/getting-started.html)
- [AdminLTE v4 — Main Sidebar](https://adminlte.io/themes/v4/docs/components/main-sidebar.html)
- [ColorlibHQ/AdminLTE no GitHub](https://github.com/ColorlibHQ/AdminLTE)
- [Redmine — Theme Bootstrap (wiki)](https://www.redmine.org/projects/redmine/wiki/ThemeBootstrap)
- [reubenmallaby/redmine_bootstrap](https://github.com/reubenmallaby/redmine_bootstrap)
- [mrliptontea/PurpleMine2](https://github.com/mrliptontea/PurpleMine2)
