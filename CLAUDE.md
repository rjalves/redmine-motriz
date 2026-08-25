# redmine-theme

Projeto para criar um tema visual próprio para o Redmine.

## Contexto obrigatório

**Antes de escrever qualquer CSS/JS de tema, leia [docs/redmine/00-INDEX.md](docs/redmine/00-INDEX.md).**

É uma base de conhecimento extraída do código-fonte oficial do Redmine
(branch `master` = 7.0 e `5.1-stable`), não de memória. Cobre o motor de temas,
estrutura de diretórios por versão, tokens de cor, mapa de seletores, ícones SVG,
limites do `theme.js`, responsivo/RTL e as armadilhas conhecidas.

Os arquivos reais do Redmine estão em `docs/redmine/reference/` —
**use `grep` neles em vez de rebuscar na web.**

## Fatos que mudam decisões

- O tema precisa de `stylesheets/application.css` com esse nome exato, senão nem aparece no dropdown.
- O nome da pasta é o id do tema e a base do rótulo (`dir.humanize`).
- **Redmine 6+/7:** tema em `themes/`. **Redmine ≤5:** em `public/themes/`.
- No Redmine 7, 341 usos de cor passam por `var(--oc-*)` (Open Color). Redefinir
  os tokens no `:root` recolore quase toda a interface.
  Exceções: `nav.top-menu` (`#234761`) e `#header` (`#3A78A3`) são hex fixo.
- `body_css_classes` entrega `controller-*`, `action-*`, `project-*`, `has-main-menu`
  no `<body>` — é o gancho para mudar usabilidade por tela sem plugin.
- O CSS core usa **propriedades lógicas** (`inline-size`, `padding-inline`…). Escreva no mesmo dialeto.
- Só `javascripts/theme.js` é auto-carregado, no `<head>`, antes do DOM existir.
- Um tema não muda views, rotas, menus nem textos — isso exige plugin.

## Estado atual

- **Tema instalado** em `redmine-7/themes/motriz/` — Redmine 7.0.0 stable, 216 KB.
  Aparece como "Motriz" em Administração → Configurações → Exibição.
- **Canvas de design** (telas aprovadas): https://claude.ai/code/artifact/a80afa4d-459b-46bd-be9c-af8dea28f2c4
  Fontes das artboards em `design/` (`_base.css` + fragmentos + `build.py`).
- **Gerador de cor** em `tools/build_tokens.py` — falha se algum par cair abaixo de AA.
- **Plugin `motriz_2`** em `redmine-7/plugins/motriz_2/` — fork do Redmine ASAP Theme
  v2.4.0 (MIT, Tantic) com paleta, tipografia e logotipo Motriz. Cores por
  `tools/build_tailwind_theme.py`. **Alternativa ao tema, não complemento**: o layout
  dele não carrega o `application.css`, então com o plugin ligado o tema `motriz` não
  pinta nada. Ver `docs/redmine/13-asap-theme-como-base.md`.
- **Plugin `motriz_kanban`** em `plugins/motriz_kanban/` — 4 arquivos, sem CSS e sem
  migração. Só acrescenta `/quadro` e `/projects/:id/quadro` ao **quadro Kanban que já
  existia dentro do `motriz_2`** e estava desligado por padrão. Depende do `motriz_2`.
  Armadilhas de menu e permissão em `docs/redmine/16-quadro-kanban.md`.
- **Painel na tela inicial** — seis indicadores e cinco gráficos em
  `motriz_2/app/views/welcome/_dashboard*`, regra em `lib/redmine_asap_theme/dashboard.rb`.
  Usa o **Chart.js 4.5.1 que o Redmine já pinava no importmap** e vinha com 0 bytes;
  repor o arquivo também consertou os gráficos nativos. Ver `docs/redmine/17-painel-inicial.md`.
- **Plugins próprios ficam em `/plugins/` na raiz**, copiados por linha explícita do
  `Dockerfile`. `redmine-7/plugins/` é reservado ao fork do tema (`motriz_2`).

## Decisões tomadas

- **Versão alvo: Redmine 7.0.0 stable** (confirmado em `redmine-7/lib/redmine/version.rb`).
  Tema em `themes/`, pipeline Propshaft, paleta Open Color, ícones SVG.
- **Escopo: redesenho de usabilidade + plugin fino.** O tema (já entregue) cobre visual,
  layout por tela e tipografia. O plugin ainda não foi feito.
- **Identidade: Motriz Digital.** Masthead verde escuro `#024b40` com o logotipo em
  negativo + título fixo "Gestão de Projetos". Paleta do brandbook Motriz (fev/2025).
- **Barra lateral à esquerda** (o core usa `row-reverse`, que a joga para a direita).
- **`#header h1` deixa de mostrar o nome do projeto** — ele continua no seletor de projeto.

## Correções aplicadas na base de conhecimento

Descobertas ao instalar no código real, contra o que a wiki oficial diz:

1. **`@import` do Redmine 7 é `url(/application.css)`**, caminho lógico raiz — não a
   forma relativa da wiki, que é do Redmine 5 e deixa a página sem estilo.
2. **`responsive.css` carrega depois do tema** e ganha nos empates de especificidade;
   traz 3 cores próprias em hex fixo. Overrides mobile precisam de `body` na frente.
3. **Caminhos lógicos de asset achatam o subdiretório**: `images/logo.svg` vira
   `themes/motriz/logo.svg`. Nomes precisam ser únicos entre subpastas.
   Vale igual para plugins (`assets/stylesheets/x.css` → `plugin_assets/<id>/x.css`).
4. **O tutorial de plugins da wiki é da era Redmine 3/4.** `require_dependency` no
   `init.rb` quebra o Zeitwerk do 7.0; assets não são mais copiados para
   `public/plugin_assets`. Divergências completas no doc 14.

## Pendências

- [ ] **SVG oficial da Motriz Digital** (versão negativa) para
      `themes/motriz/images/logo-motriz-digital.svg` — hoje é placeholder
- [ ] **Ícone oficial** para `themes/motriz/favicon/favicon.svg` — hoje é placeholder
- [ ] Mapear os identificadores reais dos projetos na seção 15 do CSS (cor por frente)
- [ ] Mapear os ids reais de situação das tarefas (seção 15)
- [ ] Aval da Comunicação sobre os tons derivados para estados de interface
- [ ] Plugin fino, se necessário — fronteira em `docs/redmine/09-plugin-fino.md`,
      API completa em `docs/redmine/14-plugins-tutorial.md`
- [ ] Confirmar as 3 inconsistências do brandbook (`docs/redmine/10-identidade-motriz.md`)
