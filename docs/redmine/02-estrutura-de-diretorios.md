# 02 — Estrutura de diretórios e o corte do Redmine 6.0

## A quebra que importa

O Redmine 6.0 trocou o Sprockets pelo **Propshaft** e moveu os assets. Isso mudou
onde o tema mora. Errar o local = tema invisível no dropdown.

| | Redmine ≤ 5.x | Redmine 6.0+ e 7.x |
|---|---|---|
| Pasta do tema | `public/themes/<nome>/` | `themes/<nome>/` (raiz do app) |
| CSS core a importar | `public/stylesheets/application.css` | `app/assets/stylesheets/application.css` |
| Temas nativos | `public/themes/{alternate,classic}` | `app/assets/themes/{alternate,classic}` |
| Pipeline | Sprockets | Propshaft (digest/hash nos nomes) |
| Ícones | PNG raster (`images/*.png`) | sprite SVG (`icons.svg`) — raster removido no 7.0 |

## Estrutura completa de um tema (6.0+/7.x)

```
themes/
  └─ <nome_do_tema>/          ← o nome desta pasta é o id E a base do rótulo
       ├─ stylesheets/
       │    └─ application.css      ← OBRIGATÓRIO
       ├─ javascripts/
       │    └─ theme.js             ← opcional; só este nome é auto-carregado
       ├─ images/
       │    ├─ icons.svg            ← opcional; sobrescreve ícones do sprite
       │    └─ logo.png
       ├─ favicon/
       │    └─ favicon.png          ← opcional; coloque UM arquivo só
       ├─ fonts/                    ← opcional; qualquer subdir vira asset path
       │    └─ ...
       └─ src/                      ← IGNORADO pelo asset pipeline (use p/ Sass, SVG fonte)
```

Para Redmine ≤ 5.x é a mesma árvore, só que dentro de `public/themes/`.

## O `@import` do CSS core

Todo tema começa reimportando o CSS base — senão você herda uma página sem estilo.

**Redmine ≤ 5.x** (a forma da wiki oficial, caminho relativo saindo do tema):

```css
@import url(../../../stylesheets/application.css);
```

Contagem do caminho: de `public/themes/<tema>/stylesheets/` sobem-se 3 níveis
(`stylesheets` → `<tema>` → `themes` → `public`), chegando em
`public/stylesheets/application.css`.

**Redmine 6.0+/7.x** — **a forma relativa NÃO funciona.** Verificado no código:
os dois temas nativos do Redmine 7 (`app/assets/themes/alternate` e `classic`) usam
o **caminho lógico raiz**:

```css
@import url(/application.css);
```

O Propshaft reescreve isso no boot para `/assets/application-<hash>.css`. O hash muda
a cada build — **nunca escreva o caminho com digest à mão**.

> A wiki oficial ainda mostra `@import url(../../../stylesheets/application.css)`,
> que é a forma do Redmine 5. Em um tema para 6/7 ela não resolve e a página sai sem
> estilo nenhum. Confira sempre contra `app/assets/themes/*/stylesheets/application.css`
> da versão alvo.

## Servidor web no Redmine 6.0+

A wiki oficial registra que o 6.0 exige configuração adicional do servidor:
criar um alias de `/public/assets/themes` para `/themes` (exemplo dado para
Apache2). Sem isso, os assets do tema (imagens, fontes) podem não ser servidos em
produção, embora o CSS funcione.

> **A confirmar no ambiente alvo.** Em muitas instalações com `RAILS_ENV=production`
> e `rake assets:precompile`, os assets do tema são copiados para `public/assets`
> e o alias não é necessário. Verifique servindo uma imagem do tema direto pela URL
> antes de assumir.

## Instalação e ativação

1. Copiar a pasta do tema para o local correto da versão
2. **Reiniciar o Redmine** (a lista de temas é memoizada em `@@installed_themes`)
3. Administração → Configurações → Exibição → Tema → selecionar → Salvar
4. Redmine 6.0+: a compilação de assets acontece no startup

Em produção, se você usa precompile:
```bash
RAILS_ENV=production bin/rails assets:precompile
```

## Convenção de nome da pasta

O rótulo no dropdown é `dir.humanize` — só a primeira letra fica maiúscula e
`_`/`-` viram espaço:

| Pasta | Rótulo exibido |
|---|---|
| `motriz` | Motriz |
| `motriz_dark` | Motriz dark |
| `motriz-dark` | Motriz-dark |
| `MotrizDark` | Motrizdark |

Use `snake_case` minúsculo. Evite hífen (não é convertido em espaço) e evite
CamelCase (`humanize` faz downcase do resto).
