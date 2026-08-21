# 11 — Mapeamento: paleta Motriz → tokens do Redmine

Gerado e validado por `tools/build_tokens.py` (roda com `python3 build_tokens.py`).
Todos os 16 pares de contraste críticos passam em AA.

## O princípio

O Redmine 7 consome cor por `var(--oc-*)` em 341 lugares
([03](03-tokens-e-cores.md)). Redefinimos esses tokens com a paleta Motriz e a
interface inteira acompanha. Onde uma cor da marca não atinge contraste como texto,
usamos uma **derivação que preserva a matiz em OKLCH** e escurece só até cruzar 4,5:1.

> **Exceção declarada à regra "não usar cores fora da paleta".**
> O brandbook proíbe cores fora da paleta em *peças de marca*. Uma interface precisa
> de estados (link, hover, foco, erro, desabilitado) que a paleta de 8 cores não
> cobre com contraste legível. As derivações abaixo **mantêm a matiz exata** da cor
> institucional de origem e só alteram luminosidade. Nenhuma matiz nova foi
> inventada. Confirmar com Comunicação antes de publicar.

## Armadilhas encontradas no core (motivo de cada escolha)

Verificado linha a linha em `reference/redmine7-core-application.css`:

| Token | Onde o core usa | Por que importa |
|---|---|---|
| `--oc-red-9` | `a:hover` **e** `tr.overdue td.due_date` **e** `span.required` **e** `.tabular label.error` **e** `div.wiki a.new` | **Acumula hover e alerta.** Não dá para separar sem sobrescrever seletor. O laranja Motriz serve aos dois (é a cor de atenção da marca) |
| `--oc-red-8` | `.badge-private` **fundo com texto branco**, borda de nota privada, `.icon-error` | Precisa de ≥4,5:1 **com branco por cima** — mais escuro que o red-9 |
| `--oc-green-7` | `table.progress td.closed` **e** `.avatar-color-3` fundo com texto branco | O `#5ba046` puro dá só 3,20:1 com branco — **falharia nas iniciais dos avatares** |
| `--oc-blue-7` | fundo de hover de menu **e** `.avatar-color-5`, ambos com texto branco | Tem de ser escuro: usamos o verde institucional puro |
| `--oc-blue-9` | `a, a:link, a:visited` **e** stroke dos ícones | É **a** cor de link do Redmine |
| `--oc-indigo-5` | `.badge-count` fundo com texto branco **e** valor de `--color-current-marker` | Conflito: o marcador quer cor viva, o badge quer fundo escuro. Resolvido definindo `--color-current-marker` à parte |
| `--oc-gray-4` | 45 usos — **as bordas** | Token de maior alcance visual depois do branco |
| `--oc-gray-7` | títulos **e** itens de dropdown **e** mais 18 usos | **Não** vira verde: verde só nos títulos, por seletor |

## Escala neutra

Ancorada nos dois cinzas do brandbook, que caem quase exatamente onde o Open Color
os colocaria (`#dfe1e3` → L 0,909 ≈ `gray-3`; `#6d6e71` → L 0,538). Matiz e croma
copiados do próprio cinza da marca (levemente frio, C ≈ 0,004).

| Token | HEX | Papel |
|---|---|---|
| `--oc-gray-0` | `#f6f9fb` | fundo da sidebar |
| `--oc-gray-1` | `#f0f2f4` | fundos sutis |
| `--oc-gray-2` | `#e8ebed` | cabeçalho de tabela |
| `--oc-gray-3` | `#dfe1e3` | **cinza claro da marca** |
| `--oc-gray-4` | `#cacccf` | **bordas** (45 usos) |
| `--oc-gray-5` | `#9c9fa1` | texto do rodapé, placeholders |
| `--oc-gray-6` | `#6d6e71` | **cinza escuro da marca** — texto secundário |
| `--oc-gray-7` | `#4d4f51` | texto forte |
| `--oc-gray-8` | `#36383a` | — |
| `--oc-gray-9` | `#212325` | texto principal (15,77:1) |

## Tokens cromáticos

| Token | HEX | Derivado de | Papel no Redmine |
|---|---|---|---|
| `--oc-blue-9` | `#00747c` | ciano `#26c1c8` | **links** e stroke de ícone — 5,54:1 |
| `--oc-blue-7` | `#024b40` | verde escuro (puro) | fundo de hover de menu, avatar |
| `--oc-blue-0` | `#e5f8f9` | ciano | fundo de destaque |
| `--oc-red-9` | `#ce4b03` | laranja `#f36d36` | hover, atraso, obrigatório — 4,53:1 |
| `--oc-red-8` | `#be3b00` | laranja | badge privado, erro — 5,50:1 c/ branco |
| `--oc-green-7` | `#41852b` | verde Educação `#5ba046` | progresso concluído, avatar — 4,55:1 |
| `--oc-green-8` | `#3a7e23` | verde Educação | ícone de OK |
| `--oc-green-9` | `#216600` | verde Educação | texto de sucesso |
| `--oc-yellow-9` | `#a56a00` | amarelo `#ffc033` | aviso — 4,51:1 |
| `--oc-yellow-0` | `#fff4e0` | amarelo | fundo de aviso |
| `--oc-indigo-0` | `#e8f9f4` | verde escuro | **fundo do `#main-menu`** |
| `--oc-indigo-1` | `#daf3ed` | verde escuro | fundo do item selecionado na sidebar |
| `--oc-indigo-5` | `#00804e` | verde claro `#4dcb93` | fundo de `.badge-count` — 5,00:1 |
| `--oc-indigo-9` | `#024b40` | verde escuro (puro) | item selecionado |
| `--oc-cyan-6` | `#007e86` | ciano | avatar |
| `--oc-grape-7` | `#5c2e91` | violeta (puro) | avatar |

Semânticos e as duas cores fora de token:

| Alvo | Valor | Observação |
|---|---|---|
| `--fonts-main` | `"Archivo", …` | ver [10](10-identidade-motriz.md) |
| `--color-current-marker` | `#4dcb93` | verde claro puro — é filete decorativo, não texto |
| `nav.top-menu` | `#024b40` | hex fixo no core, exige sobrescrita |
| `#header` | `#024b40` | hex fixo; **obrigatório** pela regra de fundo do logo |
| títulos `#content h1..h6`, `#sidebar h3` | `#024b40` | por seletor, não por token |

## Validação de contraste

| Par | Medido | Mínimo |
|---|---:|---:|
| link sobre branco | 5,54:1 | 4,5 |
| hover/atraso sobre branco | 4,53:1 | 4,5 |
| branco sobre badge privado | 5,50:1 | 4,5 |
| branco sobre avatar verde | 4,55:1 | 4,5 |
| branco sobre avatar verde escuro | 10,08:1 | 4,5 |
| branco sobre avatar ciano | 4,85:1 | 4,5 |
| branco sobre avatar violeta | 9,31:1 | 4,5 |
| branco sobre badge-count | 5,00:1 | 4,5 |
| aviso sobre branco | 4,51:1 | 4,5 |
| texto secundário | 5,10:1 | 4,5 |
| texto principal | 15,77:1 | 4,5 |
| títulos verde institucional | 10,08:1 | 4,5 |
| selecionado na sidebar | 8,65:1 | 4,5 |
| branco sobre masthead | 10,08:1 | 4,5 |
| verde claro sobre masthead | 4,93:1 | 4,5 |
| borda sobre branco | 1,61:1 | 1,5 |

## Cor por projeto (frentes e programas)

A arquitetura de marcas mapeia direto em `body.project-<identifier>`:

```css
body.project-educacao            #header { background: #024b40; }
body.project-educacao            #main-menu .selected { border-block-end-color: #5ba046; }
body.project-liderancas          #main-menu .selected { border-block-end-color: #f36d36; }
body.project-trainee-gestao      #main-menu .selected { border-block-end-color: #5c2e91; }
body.project-liderancas-negras   #main-menu .selected { border-block-end-color: #4a1702; }
body.project-liderancas-exec     #main-menu .selected { border-block-end-color: #253b61; }
```

O `#header` continua `#024b40` em todos (regra de fundo do logo). A cor da frente
entra como **filete de acento**, não como fundo — assim a marca-mãe não se perde.
Os identificadores acima são placeholders: usar os reais do Redmine da Motriz.

## Efeito colateral a conferir

`.avatar-color-1..N` reaproveita `yellow-4`, `green-7`, `cyan-6`, `blue-7`,
`grape-7`. Redefinir esses tokens **muda as cores dos avatares** — já validados
acima para texto branco, mas vale olhar lado a lado se ficam distinguíveis entre si.
