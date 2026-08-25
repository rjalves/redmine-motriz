# Painel da tela inicial — indicadores e gráficos

## O problema

Depois do login, a home mostrava literalmente isto, em inglês:

> Projects — No recent project. / News — No news.

Enquanto a instância tinha **8 projetos e 49 tarefas, 47 abertas**.

Duas causas independentes:

1. **A home só listava projetos onde a pessoa é membro.** A consulta em
   `welcome_controller_patch.rb` faz `joins(:members).where(members: {user_id:})`.
   Um administrador — que enxerga tudo mas costuma não ser membro de nada —
   caía em "nenhum projeto recente" tendo dezenas de projetos visíveis.
2. **A árvore `welcome.*` não tinha tradução pt-BR.** Como
   `config.i18n.fallbacks = true`, a tela inteira caía no inglês.

## A biblioteca de gráficos: o Redmine já tinha uma, vazia

O pedido citava o `rails_charts` como exemplo. Ao investigar, apareceu algo
melhor:

`redmine-7/config/importmap.rb:12` já traz
`pin "chart.js", preload: false, to: "chart.min.js" # @4.5.1`, e dois controllers
Stimulus do core consomem esse módulo:

- `app/javascript/controllers/reports/details_controller.js:14`
- `app/javascript/controllers/repositories/stats_controller.js:11`

Ambos fazem `import('chart.js').then(chart => ... chart.default)`.

**Mas `app/assets/javascripts/chart.min.js` tinha 0 bytes** — o único arquivo
vazio entre os 300 assets, tanto no repositório quanto na imagem em produção.
Ou seja: os gráficos nativos do Redmine (estatística de repositório e relatório
de tarefas) falhavam em silêncio desde sempre nesta instalação.

### Por que Chart.js e não rails_charts

| | Chart.js 4.5.1 | rails_charts (ECharts) |
|---|---|---|
| Já declarado no app | sim, no importmap | não |
| Instalação | repor o arquivo | gem + Gemfile de plugin + linha no Dockerfile antes do `bundle install` + pin no `importmap.rb` do core |
| Peso | 205 KB | 1,1 MB |
| Efeito colateral | conserta dois recursos nativos quebrados | nenhum |

O `rails_charts` é um Rails Engine que emite `<script>` inline e cujo instalador
edita `config/importmap.rb` e `app/javascript/application.js` — dois arquivos do
core. Instalá-lo significaria duas bibliotecas de gráfico na mesma aplicação
para resolver um problema que a primeira já resolvia.

### Como o arquivo foi reposto

O ESM oficial do Chart.js é **fatiado em chunks**
(`dist/chart.js` importa `./chunks/helpers.dataset.js`), então não serve para um
pin de arquivo único. E o build UMD não tem `export default`, que é o que o core
consome.

A solução foi empacotar `chart.js/auto` num único ESM:

```bash
npm pack chart.js@4.5.1
npx esbuild node_modules/chart.js/auto/auto.js \
  --bundle --format=esm --minify --legal-comments=inline \
  --outfile=redmine-7/app/assets/javascripts/chart.min.js
```

`auto.js` registra todos os controllers e faz `export default Chart` — exatamente
o contrato que `import('chart.js').then(c => c.default)` espera. Verificado:
`typeof default === 'function'`, `version === '4.5.1'`, 8 controllers registrados.

O arquivo é commitado, como o `application.css` do Tailwind — o Dockerfile não
roda Node.

## O painel

| Peça | Caminho (em `redmine-7/plugins/motriz_2/`) |
|---|---|
| Regra de negócio | `lib/redmine_asap_theme/dashboard.rb` |
| Dados no controller | `lib/redmine_asap_theme/welcome_controller_patch.rb` |
| Marcação | `app/views/welcome/_dashboard.html.erb` + `_dashboard_card.html.erb` |
| Gráficos | `assets/javascripts/controllers/dashboard_charts_controller.js` |
| Registro do JS | `app/views/redmine_asap_theme/_html_head.html.erb` |

Seis cartões de número (abertas, atrasadas, atribuídas a mim, sem responsável,
fechadas na semana, projetos ativos) e cinco gráficos: rosca por situação,
barras por prioridade, linha de criadas × fechadas nas últimas 12 semanas, e
barras horizontais por projeto e por responsável.

### Decisões que não são óbvias

- **Tudo parte de `Issue.visible(user)`.** O `visible_condition` do Redmine
  aplica visibilidade por papel, por módulo habilitado e por tracker. Um número
  somado fora desse escopo vazaria a existência de tarefas que a pessoa não pode
  ver. Verificado: com os mesmos dados, `admin` vê 47 abertas e o anônimo vê 1.
- **Agregação no banco, não em Ruby.** `GROUP BY` + `COUNT`, para o custo não
  crescer com o tamanho da instância. Medido: **16 consultas** para o painel
  inteiro.
- **A série temporal é a exceção**, e de propósito: `DATE_TRUNC` é dialeto do
  PostgreSQL, e o Redmine roda também em MySQL e SQLite. Os timestamps vêm por
  `pluck` e são agrupados em Ruby — o custo fica limitado pela **janela de 84
  dias**, não pelo tamanho da tabela.
- **As situações saem na ordem do fluxo (`position`), não por contagem** — é o
  mesmo eixo do Quadro, e ler os dois juntos só funciona se a ordem bater.
- **"Sem responsável" nunca é engolido pelo corte de "outros"**: é justamente a
  barra que mostra trabalho que ninguém pegou.
- **Cada cartão de número é um link** para a mesma consulta na lista de tarefas.
  Ver "12 atrasadas" e não conseguir chegar nas 12 seria frustrante.
- **As cores vêm das custom properties** (`--color-*`) que o tema publica no
  `:root`, lidas em tempo de execução. A paleta acompanha a marca e o modo
  escuro sem repetir hex no JavaScript.
- **`destroy()` no `disconnect()`**: o Turbo troca o corpo da página sem
  recarregar, e sem isso os gráficos antigos ficam presos a canvas removidos,
  segurando memória e listeners de resize.
- **O JS do painel só é carregado na home** (`controller_name == 'welcome'`),
  e o `import('chart.js')` é dinâmico — nenhuma outra tela paga os 205 KB.

## Armadilha de layout

O `<canvas>` precisa de um pai com **altura definida**. O Chart.js é responsivo
e, sem isso, mede zero e o gráfico não aparece — sem erro no console. Daí o
`altura` obrigatório em `_dashboard_card.html.erb` e o `relative` no contêiner.

## Verificação feita

Contêiner descartável da imagem de produção, banco real, sem tocar no contêiner
no ar:

- `chart.min.js` servido pelo Propshaft: 205.271 bytes, com `export default`.
- **A cadeia inteira do importmap**: `<script type="importmap">` mapeia
  `chart.js` → `/assets/chart.min-6af3eebb.js`, e esse GET devolve **200** com
  205 KB e `content-type: text/javascript`. É o elo que só o navegador
  exercitaria.
- Somas conferem: por situação, por projeto e por responsável, cada uma
  totalizando exatamente as 47 abertas.
- `GET /` → 200, 5 canvas, dados no JSON, título "Panorama" em pt-BR.
- A home passou de **9 para 137 trechos de texto visível**.

## Dívida que continua

O `en.yml` do `motriz_2` tem 132 chaves; o `pt-BR.yml` agora cobre wallpapers,
quadro e tela inicial. **O restante — atalhos de teclado, navegação rápida,
notificações — continua caindo no fallback em inglês.** Há também strings
fixas em francês dentro de alguns controllers Stimulus, herdadas do upstream.
