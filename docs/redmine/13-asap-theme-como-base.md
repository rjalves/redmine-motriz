# 13 — Redmine ASAP Theme como base: diagnóstico

Pergunta avaliada: **o `redmine_asap_theme` pode servir de base para o tema Motriz?**

Fonte: <https://github.com/tantic/redmine_asap_theme> clonado e medido em 21/08/2026
(`v2.4.1`, último commit `af53216` de 16/07/2026). Licença **MIT © 2025 Tantic**.
Autoria: DGAC/DSNA — Tantic (261 dos 269 commits).

## Veredito

**Não é base — é uma alternativa concorrente, e mutuamente exclusiva com o tema Motriz.**

Apesar do nome, **não é um tema**: é um **plugin** com `init.rb`, 6 migrations que
alteram tabelas do core, 26 arquivos de patch em Ruby, 69 views sobrescritas
(inclusive `layouts/base.html.erb`), 13 overrides Deface e duas gems extras.
É exatamente a **rota (C)** descrita em [12](12-adminlte-como-base.md) — o caminho
pesado — já implementado por terceiros, com Tailwind no lugar do Bootstrap.

E o detalhe que fecha a questão: **o `base.html.erb` dele não carrega mais o
`application.css`**. Instalar esse plugin **apaga o tema Motriz inteiro**.

## O que é, em números

| Fato | Valor |
|---|---|
| Tipo | plugin Redmine (`plugins/`), **não** tema (`themes/`) |
| Licença | MIT © 2025 Tantic |
| Versão / último commit | `v2.4.1` / 16-07-2026 |
| Commits por ano | 180 em 2024, 67 em 2025, **22 em 2026** |
| Autores | 1 principal (261/269 commits) + 3 pontuais |
| Estrelas / forks | 53 / 4 |
| Stack | Tailwind CSS 4.1 + Stimulus + Turbo |
| Views sobrescritas | **69** arquivos `.erb`, incluindo `layouts/base.html.erb` (295 linhas) |
| Patches Ruby (`*_patch.rb`) | **20** + helpers, hooks e notification listener |
| Overrides Deface | 13 |
| Migrations | **6** — duas alteram tabelas do core (`issue_statuses`, `trackers`) |
| Gems extras | `deface`, `letter_avatar` |
| CSS escrito à mão em `src/` | **237 KB / 9.971 linhas** (só `legacy.css` = 81 KB) |
| CSS compilado servido | **388 KB** (`assets/stylesheets/application.css`) |
| Repositório | 60 MB — inclui **33 MB de `node_modules` versionados** (857 arquivos) e 26 MB de wallpapers |
| `.gitignore` | **não existe** |
| `requires_redmine` no `init.rb` | **ausente** — carrega em qualquer versão, sem trava |

Compatibilidade declarada pelo próprio README: *"2.1.6 work for Redmine 6.0.x;
`>=` 2.2.0 work for Redmine 6.1.x only; 2.4.0 **should** work for Redmine 7.0
(need to be more tested)"* — e a seção de instalação diz *"This plugin has been
tested with Redmine 6.0.x and 6.1.x"*. Não há nenhum commit no histórico
mencionando 7.0.

## O ponto decisivo: ele desliga o tema Motriz

O layout que o plugin coloca no lugar do core
(`app/views/layouts/base.html.erb`, linhas 10–31) carrega:

```erb
<%= favicon %>
<%= stylesheet_link_tag 'jquery/jquery-ui-1.13.2', 'tribute-5.1.3', :media => 'all' %>
<%= stylesheet_link_tag 'rtl', :media => 'all' if l(:direction) == 'rtl' %>
…
<%= heads_for_theme %>
…
<%= stylesheet_link_tag "application.css", :plugin => 'redmine_asap_theme' %>
```

Compare com o core ([01](01-arquitetura-de-temas.md)):

```erb
<%= stylesheet_link_tag 'jquery/…', 'tribute-…', 'application', 'dropdown', 'responsive' %>
```

**`application`, `dropdown` e `responsive` sumiram.** E é justamente o
`stylesheet_link_tag 'application'` que o motor de temas intercepta para servir o
`themes/motriz/stylesheets/application.css`. Sem esse link:

| Peça do tema Motriz | Sobrevive? |
|---|---|
| `stylesheets/application.css` (801 linhas, toda a identidade) | ❌ **nunca é carregado** |
| Redefinição dos tokens `--oc-*` | ❌ o core CSS também não carrega — não há o que recolorir |
| Fontes Archivo/Bricolage embutidas | ❌ declaradas dentro do CSS que não carrega |
| `favicon/favicon.svg` | ✅ o helper `favicon` continua resolvendo pelo tema |
| `javascripts/theme.js` | ✅ `heads_for_theme` continua (hoje o Motriz não tem esse arquivo) |

O resultado de instalar os dois juntos é o pior dos mundos: a interface fica com o
visual ASAP, o favicon Motriz e nenhum CSS da marca. **Não é composição, é
substituição.**

Efeito colateral relacionado: o layout deles reintroduz `stylesheet_link_tag 'rtl'`,
mas **`rtl.css` não existe mais no Redmine 7** (conferido em
`redmine-7/app/assets/stylesheets/`) — é resquício do Redmine 5/6 que só dispara em
idiomas RTL, mas sinaliza que o layout não foi revalidado para a versão 7.

## Colisões com as decisões já tomadas neste projeto

| Decisão do projeto | O que o ASAP faz | Consequência |
|---|---|---|
| Recolorir via os 341 usos de `var(--oc-*)` ([03](03-tokens-e-cores.md)) | **zero** ocorrências de `--oc-*` em todo o CSS dele | a estratégia inteira de [11](11-mapeamento-de-tokens.md) fica sem alvo |
| Escrever em **propriedades lógicas** ([04](04-mapa-de-seletores.md), [07](07-responsivo-e-rtl.md)) | **0** `inline-size`, **0** `margin-block`, **0** `padding-inline` — contra 291 `width:`, 218 `left:`, 98 `padding-left` | dialeto oposto ao do core; RTL depende do `rtl.css` que não existe mais |
| Paleta Motriz do brandbook ([10](10-identidade-motriz.md)) | **1.057 utilitários de cor fixos no markup** (91 classes distintas): 824 `gray`, 148 `blue`, 24 `red`, 14 `amber`, 6 `indigo` | a marca só entra sequestrando as escalas `gray`/`blue` do Tailwind no `@theme` e recompilando |
| Tema trocável pelo dropdown do admin ([09](09-plugin-fino.md)) | plugin sempre ativo; para desligar, desinstalar e rodar migrations reversas | perde-se o "desliga o visual sem perder a função" |
| Plugin **fino** ([09](09-plugin-fino.md)) | 20 patches em `ApplicationHelper`, `IssuesHelper`, `IssuesController`, `ProjectsController`, `MyController`, `WelcomeController`, `UsersController`, `AccountController`, `IssueQuery`, `IssueStatus`, `Tracker`, `IssueImport`… | ordem de grandeza acima do escopo acordado |
| Não alterar estrutura de dados do Redmine | `add_color_to_issues_statuses`, `add_color_to_trackers` **alteram tabelas do core**; cria `board_card_positions` e `asap_notifications` | desinstalar exige rollback de schema |

Some-se: `init.rb` faz `delete_menu_item :project_menu, :settings` — **remove um item
de menu do core** para todos os projetos.

## Riscos de manutenção

1. **Sem `requires_redmine`.** O plugin carrega em qualquer versão do Redmine e falha
   em runtime, não no boot. Um upgrade do Redmine vira incidente em produção.
2. **20 monkey patches com `prepend`** em controllers e helpers do core. Cada versão
   maior do Redmine pode mudar a assinatura desses métodos silenciosamente.
3. **69 views congeladas em uma versão.** Correções de segurança e funcionalidade que
   o Redmine publicar nessas views não chegam à instalação — as views do plugin ganham.
4. **Bus factor 1.** 261 de 269 commits de um único autor, que se descreve no README
   como *"I'm not a designer neither a real developer"*. Ritmo caindo: 180 → 67 → 22
   commits/ano.
5. **Redmine 7 não testado.** É exatamente a nossa versão alvo
   (`redmine-7/lib/redmine/version.rb` = 7.0.0).
6. **Dependências acopladas a um ecossistema que não temos.** O `src/input.css`
   aponta `@source` para três plugins irmãos — `redmine_asap_user_features`,
   `redmine_asap_portfolio`, `redmine_asap_pilot` — de modo que o build de CSS
   pressupõe a suíte completa.
7. **33 MB de `node_modules` versionados e nenhum `.gitignore`.** Superfície de
   supply chain dentro do repositório e diffs impossíveis de revisar.
8. **`tailwind.config.js` vestigial.** É config de Tailwind v3 (`module.exports`,
   `content`, `plugins: require(...)`) num projeto que já usa Tailwind v4
   CSS-first (`@import "tailwindcss"`, `@theme`, `@plugin`, `@source`). Só o
   `input.css` vale; o `.js` engana quem for customizar.

## O que vale a pena aproveitar

A licença é MIT — dá para copiar código com atribuição. E há decisões de produto
boas ali, que valem como **especificação do que o plugin fino da Motriz poderia
fazer**, sem herdar a base de código:

| Ideia | Onde entraria no nosso escopo |
|---|---|
| **Cor por situação e por tracker configurável no admin** | é exatamente a pendência aberta de mapear "ids reais de situação" na seção 15 do CSS. A abordagem deles (coluna `color` em `issue_statuses`/`trackers` + form no admin) resolve sem hard-code — candidato natural ao plugin fino de [09](09-plugin-fino.md) |
| **Painel lateral de tarefa com edição inline** (Turbo Frames) | ganho real de usabilidade na tela mais usada; exige plugin |
| **Atalhos de teclado (`Shift+?`, `Ctrl+K`)** | cabe **no tema**, via `theme.js` ([06](06-javascript-e-usabilidade.md)) — é das poucas coisas da lista que não precisa de plugin |
| **Toggle do formulário de filtros persistido na sessão** | idem: `theme.js` + `localStorage` resolve a persistência por navegador |
| **Preferências de usuário: tema claro/escuro, tamanho de fonte, negrito em "atribuídas a mim"** | boa pauta; a parte de fonte/negrito é CSS, a persistência por usuário é plugin |
| **Página inicial com projetos favoritados** | plugin |
| **Login com wallpaper** | já temos tratamento próprio de login (seção 17 do CSS) |
| **Avatar por letra** (gem `letter_avatar`) | alternativa ao Gravatar em instalação fechada — decisão de infra, não de tema |

Vale também olhar as capturas em `doc/screenshots/` como referência de densidade e de
navegação — é um Redmine de verdade redesenhado, não um mock.

## Comparação com as rotas de [12](12-adminlte-como-base.md)

| | AdminLTE 4 | ASAP Theme |
|---|---|---|
| O que é | template de marcação (Bootstrap 5) | plugin completo (Tailwind 4 + Stimulus/Turbo) |
| Funciona no Redmine? | não sem reescrever as views | **sim, funciona hoje** (6.0/6.1) |
| Rota que representa | (A)/(B), inviáveis | **(C) já implementada** |
| Convive com o tema Motriz? | irrelevante (não roda) | **não** — desliga o CSS do tema |
| Custo de adoção | reescrever tudo | herdar 69 views + 20 patches + 6 migrations de terceiros |
| O que se aproveita | vocabulário visual | **decisões de produto** e código MIT pontual |

## Recomendação

**Não adotar como base.** Manter o tema Motriz onde está e usar o ASAP como
**benchmark funcional**: a lista de features dele é a melhor pauta disponível para
decidir o escopo do plugin fino de [09](09-plugin-fino.md) — começando por cor de
situação/tracker configurável, que já é pendência nossa.

Duas coisas da lista dele cabem **hoje, no tema**, sem plugin: atalhos de teclado e
persistência do estado do formulário de filtros. Ambas via `theme.js`, que o tema
Motriz ainda não tem.

Se algum dia a decisão for adotar o ASAP mesmo assim, registre que isso **substitui**
o tema Motriz — a identidade teria de ser reconstruída dentro do `@theme` do Tailwind
deles, sequestrando as escalas `gray` e `blue`, e passaríamos a manter um fork de 69
views do Redmine.

## Fork aplicado

Em 21/08/2026 foi feito o fork mesmo assim, por decisão do projeto:
`redmine-7/plugins/motriz_2/` — estrutura do ASAP com identidade Motriz. O que
mudou, como recompilar e o que falta verificar está no README de lá.

Dois achados da adaptação, que valem para quem for mexer no upstream:

1. **`init.rb` do ASAP quebra o boot.** A linha `require lib_dir` aponta para
   `lib/redmine_asap_theme.rb`, arquivo que não existe no repositório. `require`
   de diretório levanta `LoadError`. Verificado rodando; guardado no fork com
   `if File.exist?`.
2. **Recolorir é mais barato do que a contagem de 1.059 utilitários sugere.**
   O Tailwind v4 compila `bg-gray-900` para `var(--color-gray-900)`, então
   redefinir as escalas no `@theme` recolore tudo de uma vez. O trabalho real
   está nos 558 hex do CSS legado — e nas 71 cores de `.syntaxhl`, que precisam
   ficar de fora.

## Fontes

- [tantic/redmine_asap_theme](https://github.com/tantic/redmine_asap_theme) — código clonado e medido
- [Documentação do ASAP](https://tantic.github.io/redmine_asap_docs/docs/theme/intro)
- [tantic/redmine_asap_docker](https://github.com/tantic/redmine_asap_docker) — ambiente de teste rápido
- [redmine_asap_user_features](https://github.com/tantic/redmine_asap_user_features) — plugin irmão
