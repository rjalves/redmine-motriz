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
| 12 | [AdminLTE como base](12-adminlte-como-base.md) | Diagnóstico: por que o template AdminLTE 4 não serve de base, e o que dele se aproveita |
| 13 | [ASAP Theme como base](13-asap-theme-como-base.md) | Diagnóstico: o `redmine_asap_theme` é plugin, não tema — e desliga o CSS do tema Motriz |
| 14 | [Desenvolvimento de plugins](14-plugins-tutorial.md) | A API de plugins do Redmine 7 conferida contra o código: ciclo de carga, DSL do `init.rb`, hooks, assets, migrations, testes — e onde a wiki oficial está desatualizada |
| 15 | [Plugin `dashboard`](15-dashboard-plugin.md) | Diagnóstico: o quadro kanban do akpaevj roda no 7.0.0 e convive com o `motriz_2` — validado em contêiner contra a instância real; quatro ressalvas, a primeira de segurança |
| 16 | [Quadro Kanban](16-quadro-kanban.md) | O quadro que já existia escondido no `motriz_2`, o plugin `motriz_kanban` que dá acesso a ele, e as três armadilhas de menu/permissão de plugin que o caminho revelou |
| 17 | [Painel inicial](17-painel-inicial.md) | Indicadores e gráficos na home; o Chart.js que o Redmine já declarava mas vinha com 0 bytes — e por que ele venceu o `rails_charts` |

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
| `redmine7-hook-listener.rb` | `lib/redmine/hook/listener.rb` @ 7.0 — a base `Singleton` que se auto-registra |
| `redmine7-hook-view_listener.rb` | `lib/redmine/hook/view_listener.rb` @ 7.0 — `render_on` e os helpers já incluídos |
| `redmine7-hook-names.txt` | os 85 hooks do 7.0, agrupados por origem (view/helper/controller/lib) |
| `redmine7-lib-plugin.rb` | `lib/redmine/plugin.rb` @ 7.0 — a DSL inteira do `init.rb` |
| `redmine7-lib-plugin_loader.rb` | `lib/redmine/plugin_loader.rb` @ 7.0 — ordem de carga e autoload Zeitwerk |
| `redmine7-lib-access_control.rb` | `lib/redmine/access_control.rb` @ 7.0 — semântica de `permission` e `project_module` |
| `redmine7-lib-menu_manager.rb` | `lib/redmine/menu_manager.rb` @ 7.0 — todas as opções de item de menu |
| `redmine7-sample-plugin/` | `extra/sample_plugin` @ 7.0 — o plugin de exemplo oficial, completo |
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
- Wiki oficial — tutorial de plugins: https://www.redmine.org/projects/redmine/wiki/Plugin_Tutorial
  (desatualizada; as divergências contra o 7.0 estão na seção final do doc 14)
- Código-fonte: https://github.com/redmine/redmine
