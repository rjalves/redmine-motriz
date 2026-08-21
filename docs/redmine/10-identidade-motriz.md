# 10 — Identidade visual Motriz

Fonte: **Brandbook — Arquitetura de marcas Motriz, fevereiro 2025** (88 páginas).
Este documento extrai o que governa o tema; o PDF continua sendo a autoridade.

## Paleta institucional (marca prioritária)

| Papel | HEX | RGB | CMYK | Contraste /branco |
|---|---|---|---|---:|
| **Verde escuro institucional** | `#024b40` | 2·75·64 | 90·45·70·45 | **10,08:1** |
| Verde claro institucional | `#4dcb93` | 77·203·147 | 63·0·58·0 | 2,04:1 |
| Ciano | `#26c1c8` | 38·193·200 | 70·0·25·0 | 2,20:1 |
| Laranja | `#f36d36` | 243·109·54 | 0·71·86·0 | 2,98:1 |
| Amarelo | `#ffc033` | 255·192·51 | 0·30·90·0 | 1,64:1 |
| Branco | `#ffffff` | 255·255·255 | 0·0·0·0 | — |
| Cinza claro | `#dfe1e3` | 223·225·227 | 0·0·0·20 | 1,31:1 |
| Cinza escuro | `#6d6e71` | 109·110·113 | 0·0·0·80 | 5,10:1 |

## Paleta ampliada

| Papel | HEX | Onde |
|---|---|---|
| Verde Educação | `#5ba046` | frente Motriz Educação |
| Laranja | `#f36d36` | frente Motriz Lideranças |
| Marrom terroso | `#4a1702` | programa Lideranças Negras; Educação Amazônia |
| Violeta | `#5c2e91` | programa Trainee de Gestão Pública |
| Azul petróleo | `#253b61` | programa Lideranças Executivas |

## Achado que definiu o mapeamento

Calculado com `tools/color.py` sobre os valores do brandbook:

> **A paleta Motriz é desenhada para fundos escuros.** Sobre branco, só passam em
> contraste AA (4,5:1) o verde escuro (10,08:1), o cinza escuro (5,10:1), o marrom
> (14,85:1), o violeta (9,31:1) e o azul petróleo (11,19:1). Verde claro, ciano,
> laranja e amarelo **falham como texto sobre branco**.
>
> Sobre o verde escuro `#024b40`, porém, o verde claro dá 4,93:1 e o ciano 4,58:1
> — ambos passam.

É por isso que o logo preferencial do brandbook é o **negativo sobre verde escuro**.

Consequência para o tema: as cores vivas da marca (verde claro, ciano, amarelo)
funcionam **no masthead escuro e como preenchimento**, não como texto sobre branco.
Para texto e ícones sobre branco usamos **derivações escurecidas que preservam a
matiz** — ver [11](11-mapeamento-de-tokens.md).

## Tipografia

| Uso | Fonte | Origem |
|---|---|---|
| Títulos | **Bricolage Grotesque** (regular, medium, semibold) | Google Fonts |
| Corpo, subtítulos, blocos longos | **Archivo** | Google Fonts |
| Títulos de programas aceleradores | **Greycliff CF** | comercial — fallback oficial: Archivo |

Especificação do brandbook (p. 52):

| Elemento | Fonte | Tamanho | Entrelinha | Kerning/Tracking |
|---|---|---|---|---|
| Subtítulo | Archivo Extra Bold | 10pt | — | Optical / 0 |
| Título | Bricolage Grotesque | 36pt | 0.8 | Optical / 0 |
| Corpo | Archivo Regular | 8pt | — | Optical / 0 |

Ambas estão no Google Fonts — **o único host de fontes que o CSP dos artefatos e o
Redmine admitem sem embutir arquivo**. Para produção, prefira embutir em
`themes/motriz/fonts/` via `@font-face` (não depende de rede externa).

**Greycliff CF é comercial** — não pode ser embutida sem licença. O próprio brandbook
(p. 75) já prevê Archivo como alternativa. O tema usa Archivo; nada no Redmine
corresponde a "título de programa acelerador".

## Regras de cor de texto (p. 52)

- Sobre cores de tom escuro e médio-escuro → **texto corrido branco**
- Sobre fundo branco → **texto verde institucional ou cinza**

Aplicado no tema: títulos em `#024b40`, corpo em cinza escuro derivado.

## Regras de logo que restringem o tema

- **Só dois fundos permitidos** para o logo colorido: verde escuro institucional
  (preferencial) e branco. **Nenhum outro fundo colorido**, dentro ou fora da paleta.
  → O `#header` do Redmine, que carrega o logo, **tem de ser `#024b40` ou branco**.
- Variação preferencial: **horizontal negativa** (sobre verde escuro).
- Área de proteção = altura da letra "m" minúscula em todos os lados.
- Sobre fotografia com muita informação ou ilustração → logo monocromático branco.
- Proibido: distorcer, recolorir, aplicar contorno/sombra/textura, mudar espaçamento
  ou espessura, separar símbolo do logotipo, usar logotipo sem símbolo, aplicar na
  diagonal, reescrever em outra tipografia.

### Tamanho mínimo — ponto a confirmar

O brandbook (p. 46) lista, para web/digital:

| Variação | Valor no brandbook |
|---|---|
| Horizontal sem tagline | altura (x) = 10px / impressão 18mm |
| Vertical sem tagline | largura (x) = 30px / impressão 12mm |
| Horizontal com tagline | altura (x) = 33px / impressão 9mm |
| Vertical com tagline | largura (x) = 97px / impressão 32mm |

> **Os pares web/impressão parecem trocados** entre as linhas 1 e 3: a versão *com*
> tagline exige mais altura em web (33px > 10px) mas menos em impressão (9mm < 18mm).
> Confirmar com a área de Comunicação antes de citar esses números.
> No tema usamos o logo horizontal sem tagline a ~26px de altura no `#header`,
> folgadamente acima do mínimo em qualquer leitura.

## Arquitetura de marcas (o que mapeia para projetos do Redmine)

```
motriz                                    ← masterbrand
├── motriz | EDUCAÇÃO          #5ba046    ← frente de atuação
│   └── motriz | EDUCAÇÃO / AMAZÔNIA      ← linha descritiva
│       └── imersões temáticas (caixa arredondada, ≤30 caracteres)
│           └── comunidades de prática (caixa sólida, tipo adesivo)
├── motriz | LIDERANÇAS        #f36d36    ← frente de atuação
├── programas aceleradores (título, NUNCA submarca)
│   ├── Trainee de Gestão Pública   #5c2e91
│   ├── Lideranças Negras           #4a1702
│   └── Lideranças Executivas       #253b61
└── rede motriz                           ← submarca (única com ícone próprio)
```

**Isto casa diretamente com `body.project-<identifier>`**
([04](04-mapa-de-seletores.md)): cada frente/programa pode colorir o Redmine por
projeto sem tocar no restante do tema. É o gancho mais valioso da arquitetura de
marcas para esta aplicação.

## DNA gráfico

- Símbolo: abstração do "M" como gráfico ascendente — também lido como um "visto"
  (feito/verificado). Em ferramenta de gestão de tarefas essa leitura é um presente.
- Grafismo recorrente: **chevrons em camadas** com transparência, cantos arredondados.
- Gradiente institucional: ciano → verde claro (`#26c1c8` → `#4dcb93`), sentido
  ascendente. **Não criar novos gradientes** nem aplicá-los ao logo.
- Cantos arredondados são vocabulário da marca (caixas de imersão, submarca).

## Restrições que valem para o tema

- Não criar logos novos para eventos, trilhas ou projetos (p. 86–87)
- Não usar tipografias fora das definidas
- Não usar cores fora da paleta institucional — ver a exceção documentada e
  justificada em [11](11-mapeamento-de-tokens.md) (tons derivados para estados de UI)
- Não aplicar título junto de outros logos do ecossistema

## Inconsistências encontradas no brandbook

Registradas para confirmar com Comunicação, não corrigidas por conta própria:

1. **Violeta com dois valores.** p. 27 e p. 41: `#5c2e91` (RGB 82·45·145);
   p. 77: `#5c2d91` (RGB 92·45·145). Adotado `#5c2e91` (maioria).
2. **Tamanho mínimo do logo** — pares web/impressão aparentemente trocados (acima).
3. **Educação Amazônia** (p. 15): "o verde claro da **frente de lideranças**
   substitui o verde claro institucional" — mas a frente de Lideranças é laranja.
   Pelo contexto e pela paleta mostrada, deve ser o verde da frente de **Educação**
   (`#5ba046`).
4. **Cinza claro na paleta Educação Amazônia** (p. 15) aparece com HEX `#ffffff`
   mas CMYK 0·0·0·20 e RGB 223·225·227 — o HEX correto é `#dfe1e3`.
