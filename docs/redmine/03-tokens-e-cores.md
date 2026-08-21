# 03 — Tokens, cores e a estratégia de recoloração

Este é o documento mais acionável da base. Ele responde: **qual é o menor CSS que
recolore o Redmine inteiro?**

## O achado central

O Redmine 6+/7 carrega `open-color.css` (Open Color v1.9.1) e usa esses tokens no
CSS core. Medição feita sobre `reference/redmine7-core-application.css` (2708 linhas):

| Medida | Valor |
|---|---|
| Usos de `var(--oc-*)` | **341** |
| Hex literais totais | 73 |
| Hex literais **fora** de syntax highlighting de código | **2** |

Ou seja: **praticamente toda a cor da interface do Redmine 7 passa por variável CSS.**
Os 71 hexes restantes são cores de realce de sintaxe (`.syntaxhl`) dentro de blocos
de código — não fazem parte do chrome.

### As duas exceções **em `application.css`** (decore-as)

```css
nav.top-menu { background: #234761; /* no match in Open Color, using hex code */ }
#header      { background: #3A78A3; /* no match in Open Color, using hex code */ }
```

O próprio core comenta que não achou equivalente na paleta. **São as duas barras
mais visíveis da tela.** Qualquer tema precisa sobrescrevê-las explicitamente —
redefinir tokens não as alcança.

### Mais três em `responsive.css`

A contagem acima vale só para `application.css`. O `responsive.css` traz as suas,
todas dentro do breakpoint de 899px:

| Linha | Regra | Cor |
|---|---|---|
| 99 | `#header` (vira fixo, 64px) | `#628db6` |
| 288 | `.flyout-menu` | `#3e5b76` |
| 308–309 | `.flyout-menu h3` fundo e borda | `#628db6` / `#506a83` |

E há uma armadilha de cascata junto — ver [08](08-receitas-e-armadilhas.md).

### `--oc-yellow-0` não é cor de aviso

Vale destacar porque engana: esse token pinta o **hover das linhas de tabela**, o
**fundo do painel da tarefa** (`div.issue`) e o **índice do wiki**. Os avisos usam
`--oc-yellow-1`, `--oc-yellow-3` e `--oc-pink-9`. Tratá-lo como amarelo de alerta
deixa a tela de detalhe da tarefa com cara de aviso permanente.

## A estratégia: redefinir a paleta, não os seletores

Como o core consome tokens, você recolore o Redmine inteiro redeclarando os tokens
no `:root` do seu tema — **depois** do `@import` do core:

```css
@import url(../../../stylesheets/application.css);

:root {
  /* Redefinir os cinzas remapeia ~180 usos de uma vez */
  --oc-gray-0: #f6f7f9;
  --oc-gray-4: #d3d8e0;
  --oc-gray-6: #7b8494;
  --oc-gray-7: #454d5c;
  --oc-gray-9: #1b1f27;

  /* Trocar a hue de ação muda links, ícones, foco */
  --oc-blue-7: #1c5fd6;
  --oc-blue-9: #14408f;

  /* Menu de projeto */
  --oc-indigo-0: #eef1fb;
  --oc-indigo-9: #232f66;
}

/* As duas que NÃO são token */
nav.top-menu { background: #1a2b45; }
#header      { background: #24406b; }
```

Isso já entrega um tema coerente com pouquíssimas linhas. Refinamento vem depois,
seletor a seletor.

### Cuidado com `-rgb`

Cada token tem um par:

```css
--oc-gray-9: #212529;
--oc-gray-9-rgb: 33, 37, 41;
```

O core usa a variante `-rgb` em `rgba(var(--oc-gray-9-rgb), 0.5)` (8 ocorrências de
`--oc-gray-9-rgb`). **Se redefinir `--oc-X`, redefina o `-rgb` correspondente** —
senão sombras e overlays ficam com a cor antiga.

## Tokens mais usados pelo core (onde mexer primeiro)

| Token | Usos | Onde aparece |
|---|---:|---|
| `--oc-white` | 51 | fundo de `#content`, `#footer`, `#wrapper`, texto do header |
| `--oc-gray-4` | 45 | **bordas** em geral (tabelas, `#sidebar`, `#footer`) |
| `--oc-gray-6` | 35 | texto secundário, metadados |
| `--oc-gray-7` | 20 | títulos `h1..h6` de `#content`, `#sidebar h3` |
| `--oc-gray-5` | 17 | texto do `#footer`, placeholders |
| `--oc-gray-2` | 14 | texto do `nav.top-menu`, fundos sutis |
| `--oc-red-9` | 12 | **hover de ícones e links de ação** |
| `--oc-blue-7` | 12 | links |
| `--oc-blue-9` | 12* | estado normal de ícones (`stroke`) |
| `--oc-gray-9` / `-rgb` | 8 + 8 | texto principal, overlays |
| `--oc-gray-0` | 8 | fundo do `#sidebar` |
| `--oc-indigo-0` | — | **fundo do `#main-menu`** |
| `--oc-indigo-9` | 5 | item selecionado no sidebar |

\* soma de usos em `stroke:` e `fill:` das regras de ícone.

Único token semântico definido pelo core:

```css
:root {
  --fonts-main: "Noto Sans", sans-serif;
  --color-current-marker: var(--oc-indigo-5);
}
```

`--fonts-main` é o gancho oficial de tipografia — troque-o em vez de sobrescrever
`body { font-family }`.

## Famílias disponíveis no Open Color

13 famílias, escalas 0 (mais clara) → 9 (mais escura):

```
gray  red  pink  grape  violet  indigo  blue  cyan  teal  green  lime  yellow  orange
```

Todas já estão carregadas — você pode **usar** `var(--oc-teal-6)` no seu tema sem
declarar nada.

## Dois modelos de tema

**A) Retint** — mantém a estrutura, troca a paleta. Redefine `:root` + as 2 exceções.
Pouco CSS, baixa manutenção, sobrevive bem a upgrades do Redmine.

**B) Redesign** — muda espaçamento, densidade, hierarquia, componentes.
Exige sobrescrever seletores estruturais ([04](04-mapa-de-seletores.md)) e aceita
manutenção a cada versão maior do Redmine.

Para "alterar toda a usabilidade" o caminho é **B com a base de A**: comece
redefinindo tokens (ganho imediato e barato), depois ataque layout.

## Tema escuro

Não existe modo escuro nativo. Dá para fazer invertendo a escala de cinza nos tokens:

```css
:root {
  --oc-white: #14171c;      /* fundos de conteúdo */
  --oc-gray-0: #1a1e25;
  --oc-gray-1: #21262e;
  --oc-gray-2: #2a3039;
  --oc-gray-4: #3a424e;     /* bordas */
  --oc-gray-5: #7d8794;
  --oc-gray-6: #98a1ae;
  --oc-gray-7: #c9d0da;     /* títulos */
  --oc-gray-9: #eef1f5;     /* texto principal */
  --oc-gray-9-rgb: 238, 241, 245;
  --oc-black: #ffffff;
}
```

**Não é suficiente sozinho.** Falta tratar depois:
- os 71 hexes de `.syntaxhl` (blocos de código ficam ilegíveis em fundo escuro)
- imagens e avatares com fundo branco
- o Gantt e o calendário (`gantt.css`, `.cal`)
- anexos/preview de arquivos

Ver [08](08-receitas-e-armadilhas.md).

## Redmine ≤ 5.x é outro jogo

O `open-color.css` **não existe** antes do 6.0. O `reference/redmine51-core-application.css`
usa hex literal em toda parte. Num tema para Redmine 5 não há atalho: é sobrescrita
seletor a seletor. Veja `reference/redmine51-theme-alternate.css` (78 linhas) e
`redmine51-theme-classic.css` (49 linhas) como exemplos oficiais de escopo mínimo.
