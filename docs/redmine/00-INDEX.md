# Base de conhecimento — Temas do Redmine

Contexto técnico permanente para o projeto `redmine-theme`.
Tudo aqui foi extraído **do código-fonte oficial do Redmine** (branch `master` = 7.0
e `5.1-stable`) e da wiki oficial, não de memória. Consulte antes de escrever CSS.

Coletado em **21/08/2026**. Versão mais recente do Redmine na época: **7.0.0**
(tags disponíveis: 7.0.0, 6.1.3, 6.1.2, 6.1.1, 6.1.0, 6.0.x, 5.1.x).

## Documentos

| # | Arquivo | O que resolve |
|---|---------|---------------|
| 01 | [Arquitetura de temas](01-arquitetura-de-temas.md) | Como o Redmine descobre, carrega e aplica um tema (`lib/redmine/themes.rb` linha a linha) |
| 02 | [Estrutura de diretórios](02-estrutura-de-diretorios.md) | Onde os arquivos ficam em cada versão; o corte do Redmine 6.0 |
| 03 | [Tokens e cores](03-tokens-e-cores.md) | Open Color, a estratégia de recoloração global, o que **não** é variável |
| 04 | [Mapa de seletores](04-mapa-de-seletores.md) | Layout HTML, IDs estruturais, `body_css_classes` — os ganchos de usabilidade |
| 05 | [Ícones SVG](05-icones-svg.md) | Sprite `icons.svg`, override por ícone, como recolorir |
| 06 | [JavaScript e usabilidade](06-javascript-e-usabilidade.md) | `theme.js`, o que dá e o que não dá para mudar sem plugin |
| 07 | [Responsivo e RTL](07-responsivo-e-rtl.md) | Breakpoints reais, menu flyout mobile, propriedades lógicas |
| 08 | [Receitas e armadilhas](08-receitas-e-armadilhas.md) | Boilerplate pronto + os erros que quebram tema em produção |
| 09 | [O plugin fino](09-plugin-fino.md) | Fronteira tema/plugin, hooks de view, esqueleto do plugin |
| 10 | [Identidade Motriz](10-identidade-motriz.md) | Paleta, tipografia, regras de logo e arquitetura de marcas do brandbook |
| 11 | [Mapeamento de tokens](11-mapeamento-de-tokens.md) | Paleta Motriz → tokens do Redmine, com contraste validado |

## Fontes de referência (`reference/`)

Cópias locais dos arquivos reais — **prefira `grep` nelas a rebuscar na web**:

| Arquivo | Origem |
|---|---|
| `redmine7-core-application.css` | `app/assets/stylesheets/application.css` @ master — 2708 linhas, o CSS que você vai sobrescrever |
| `redmine7-open-color.css` | `app/assets/stylesheets/open-color.css` @ master — a paleta completa |
| `redmine7-responsive.css` | `app/assets/stylesheets/responsive.css` @ master |
| `redmine7-dropdown.css` | `app/assets/stylesheets/dropdown.css` @ master |
| `redmine7-legacy-icons-compat.css` | compat de ícones raster removidos no 7.0 |
| `redmine7-layout-base.html.erb` | `app/views/layouts/base.html.erb` @ master — a árvore DOM de toda página |
| `redmine7-icons.svg` | o sprite oficial (117 ícones) |
| `redmine7-icon-names.txt` | lista dos 117 nomes de ícone |
| `redmine-lib-themes.rb` | `lib/redmine/themes.rb` — o motor de temas |
| `redmine-icons_helper.rb` | `app/helpers/icons_helper.rb` — resolução de sprite |
| `redmine-lib-hook.rb` | `lib/redmine/hook.rb` — API de hooks para o plugin |
| `redmine51-core-application.css` | o core do 5.1 (1943 linhas), para quem alvejar Redmine 5 |
| `redmine51-responsive.css` | responsive do 5.1 |
| `redmine51-theme-alternate.css` | tema nativo `alternate` (78 linhas) — exemplo minimalista |
| `redmine51-theme-classic.css` | tema nativo `classic` (49 linhas) — exemplo minimalista |

> Os temas nativos `alternate` e `classic` **saíram de `public/themes/` no Redmine 6**
> e hoje vivem em `app/assets/themes/`. As cópias aqui são da 5.1 porque é onde o
> código-fonte deles está publicamente legível como exemplo.

## Fontes externas

- Wiki oficial — criar tema: https://www.redmine.org/projects/redmine/wiki/HowTo_create_a_custom_Redmine_theme
- Wiki oficial — temas: https://www.redmine.org/projects/redmine/wiki/Themes
- Código-fonte: https://github.com/redmine/redmine
