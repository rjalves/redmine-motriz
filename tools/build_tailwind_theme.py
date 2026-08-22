"""
Gera a paleta Motriz para o plugin motriz_2 (fork do Redmine ASAP Theme).

Duas saídas:

1. O bloco `@theme` do Tailwind v4 — escalas de 11 degraus (50…950) para as
   famílias que o ASAP realmente usa. Como o Tailwind v4 compila `bg-gray-900`
   para `background-color: var(--color-gray-900)`, redefinir a escala recolore
   todos os utilitários de uma vez.

2. O mapa de remapeamento dos hex literais do CSS escrito à mão (`assets/src/`),
   que não passam por utilitário nenhum.

Falha se algum par de contraste crítico cair abaixo de AA (4,5:1).
Rode: python3 build_tailwind_theme.py
"""
import re
import sys
from pathlib import Path

from color import hex2oklch, oklch2hex, contrast, darken_to

# ---------------------------------------------------------------------------
# Paleta do brandbook (fev/2025) — mesma fonte de build_tokens.py
# ---------------------------------------------------------------------------
MARCA = {
    'verde_escuro': '#024b40', 'verde_claro': '#4dcb93', 'ciano': '#26c1c8',
    'laranja': '#f36d36', 'amarelo': '#ffc033', 'verde_educacao': '#5ba046',
    'marrom': '#4a1702', 'violeta': '#5c2e91', 'azul_petroleo': '#253b61',
    'branco': '#ffffff', 'cinza_claro': '#dfe1e3', 'cinza_escuro': '#6d6e71',
}

DEGRAUS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]

# Curva de luminosidade espelhando a do Tailwind v4, para que a troca de paleta
# não mude o "peso" percebido de nenhuma tela do ASAP.
L_TW = {50: .985, 100: .967, 200: .928, 300: .872, 400: .707, 500: .551,
        600: .446, 700: .373, 800: .278, 900: .210, 950: .130}
# Croma: baixo nos extremos (fundos e textos), cheio no meio.
C_TW = {50: .012, 100: .024, 200: .046, 300: .072, 400: .108, 500: .132,
        600: .140, 700: .124, 800: .100, 900: .078, 950: .052}

# Escala neutra: croma quase nulo, matiz do cinza da marca (levemente frio).
_, _, H_CINZA = hex2oklch(MARCA['cinza_claro'])
C_NEUTRO = .004


def escala_neutra():
    """Neutros ancorados nos dois cinzas do brandbook."""
    e = {d: oklch2hex(L_TW[d], C_NEUTRO, H_CINZA) for d in DEGRAUS}
    # #dfe1e3 (L .909) cai entre 200 e 300; #6d6e71 (L .538) cai em 500.
    e[200] = MARCA['cinza_claro']
    e[500] = MARCA['cinza_escuro']
    return e


def escala_cromatica(base_hex):
    """Preserva a matiz exata da cor da marca; só varia L e croma."""
    _, _, H = hex2oklch(base_hex)
    return {d: oklch2hex(L_TW[d], C_TW[d], H) for d in DEGRAUS}


# Que família Motriz responde por cada escala do Tailwind usada pelo ASAP.
# Contagem de uso medida nas views: gray 853, blue 153, red 25, amber 14,
# indigo 9, orange 2, green 2, slate 1.
FAMILIAS = {
    'blue':   MARCA['ciano'],           # ação: links, botão primário, item ativo
    'red':    MARCA['laranja'],         # erro e atenção — a marca não tem vermelho
    'orange': MARCA['laranja'],
    'amber':  MARCA['amarelo'],         # aviso
    'yellow': MARCA['amarelo'],
    'green':  MARCA['verde_educacao'],  # sucesso, progresso
    'emerald': MARCA['verde_claro'],
    'teal':   MARCA['verde_escuro'],
    'indigo': MARCA['violeta'],         # acento secundário, distinto do azul
    'violet': MARCA['violeta'],
    'purple': MARCA['violeta'],
    # Famílias que o ASAP não usa hoje. Ficam mapeadas mesmo assim: se amanhã
    # alguém escrever `bg-sky-500` numa view, sai cor da marca, não do Tailwind.
    'cyan':    MARCA['ciano'],
    'sky':     MARCA['ciano'],
    'lime':    MARCA['verde_claro'],
    'fuchsia': MARCA['violeta'],
    'pink':    MARCA['laranja'],
    'rose':    MARCA['laranja'],
}

ESCALAS = {'gray': escala_neutra(), 'slate': escala_neutra(), 'zinc': escala_neutra(),
           'neutral': escala_neutra(), 'stone': escala_neutra()}
for fam, base in FAMILIAS.items():
    ESCALAS[fam] = escala_cromatica(base)

# ---------------------------------------------------------------------------
# Ajustes deliberados: onde o papel na interface exige um valor específico.
# ---------------------------------------------------------------------------
# O verde escuro institucional é a cor de superfície da marca: é ele que pinta
# a navbar, o slot do logo e o item ativo. Fixá-lo nos degraus 700/800 garante
# que `bg-blue-700` seja exatamente a cor do brandbook, não uma aproximação.
ESCALAS['blue'][700] = MARCA['verde_escuro']
ESCALAS['blue'][800] = darken_to(MARCA['verde_escuro'], 12.0)
ESCALAS['blue'][600] = darken_to(MARCA['ciano'], 4.6)    # botão primário c/ texto branco
ESCALAS['blue'][500] = darken_to(MARCA['ciano'], 3.2)
# Links e textos de ação sobre branco precisam cruzar 4,5:1.
ESCALAS['blue'][900] = darken_to(MARCA['ciano'], 8.0)
ESCALAS['red'][600] = darken_to(MARCA['laranja'], 4.6)
ESCALAS['red'][700] = darken_to(MARCA['laranja'], 6.0)
ESCALAS['amber'][600] = darken_to(MARCA['amarelo'], 4.6)
ESCALAS['amber'][700] = darken_to(MARCA['amarelo'], 6.0)
ESCALAS['green'][600] = darken_to(MARCA['verde_educacao'], 4.6)
ESCALAS['green'][700] = darken_to(MARCA['verde_educacao'], 6.0)
ESCALAS['indigo'][600] = darken_to(MARCA['violeta'], 5.0)
ESCALAS['indigo'][700] = MARCA['violeta']

# Cores de apoio do masthead, expostas como tokens próprios.
LOGO_BG = MARCA['verde_escuro']
LOGO_BG_HOVER = oklch2hex(*(lambda L, C, H: (min(.99, L + .07), C, H))(*hex2oklch(MARCA['verde_escuro'])))

# ---------------------------------------------------------------------------
# Contraste — os pares que a interface do ASAP realmente produz
# ---------------------------------------------------------------------------
BRANCO, PRETO = '#ffffff', '#000000'
G = ESCALAS['gray']

CHECKS = [
    ('texto secundário sobre branco',      G[500], BRANCO, 4.5),
    ('texto forte sobre branco',           G[700], BRANCO, 4.5),
    ('texto principal sobre branco',       G[900], BRANCO, 4.5),
    ('texto sobre fundo sutil',            G[700], G[100], 4.5),
    ('link/ação sobre branco',             ESCALAS['blue'][600], BRANCO, 4.5),
    ('link/ação forte sobre branco',       ESCALAS['blue'][700], BRANCO, 4.5),
    ('branco sobre botão primário',        BRANCO, ESCALAS['blue'][600], 4.5),
    ('branco sobre navbar/logo',           BRANCO, LOGO_BG, 4.5),
    ('branco sobre navbar hover',          BRANCO, LOGO_BG_HOVER, 4.5),
    ('branco sobre erro',                  BRANCO, ESCALAS['red'][600], 4.5),
    ('branco sobre aviso',                 BRANCO, ESCALAS['amber'][600], 4.5),
    ('branco sobre sucesso',               BRANCO, ESCALAS['green'][600], 4.5),
    ('branco sobre acento violeta',        BRANCO, ESCALAS['indigo'][600], 4.5),
    ('erro sobre branco',                  ESCALAS['red'][600], BRANCO, 4.5),
    ('aviso sobre branco',                 ESCALAS['amber'][600], BRANCO, 4.5),
    ('sucesso sobre branco',               ESCALAS['green'][600], BRANCO, 4.5),
    # modo escuro: o ASAP usa dark:bg-gray-900/800 com dark:text-gray-300/400
    ('texto claro sobre fundo escuro',     G[300], G[900], 4.5),
    ('texto secundário no escuro',         G[400], G[900], 4.5),
    ('texto sobre cartão escuro',          G[300], G[800], 4.5),
    ('ação no escuro',                     ESCALAS['blue'][300], G[900], 4.5),
    ('erro no escuro',                     ESCALAS['red'][300], G[900], 4.5),
    ('sucesso no escuro',                  ESCALAS['green'][300], G[900], 4.5),
]


def valida():
    falhas = []
    print('Contraste (mínimo AA 4,5:1)')
    print('-' * 62)
    for nome, fg, bg, alvo in CHECKS:
        r = contrast(fg, bg)
        ok = r >= alvo
        print(f'  {"OK " if ok else "FALHA"}  {nome:<34} {r:5.2f}:1  {fg} / {bg}')
        if not ok:
            falhas.append((nome, fg, bg, r, alvo))
    print()
    return falhas


# ---------------------------------------------------------------------------
# Saída 1: bloco @theme
# ---------------------------------------------------------------------------
ORDEM = ['gray', 'slate', 'zinc', 'neutral', 'stone', 'blue', 'sky', 'cyan',
         'teal', 'emerald', 'green', 'lime', 'yellow', 'amber', 'orange', 'red',
         'rose', 'pink', 'fuchsia', 'purple', 'violet', 'indigo']


def bloco_theme():
    L = []
    L.append('/* ==========================================================================')
    L.append('   Paleta Motriz — gerado por tools/build_tailwind_theme.py. NÃO editar à mão.')
    L.append('')
    L.append('   O Tailwind v4 compila `bg-gray-900` para `var(--color-gray-900)`, então')
    L.append('   redefinir as escalas aqui recolore os 1.059 utilitários das views de uma')
    L.append('   vez. As matizes vêm do brandbook Motriz (fev/2025); só L e croma variam.')
    L.append('   ========================================================================== */')
    L.append('@theme {')
    L.append('  /* Tipografia da marca */')
    L.append('  --font-sans: "Archivo", "Helvetica Neue", Arial, sans-serif;')
    L.append('  --font-display: "Bricolage Grotesque", "Archivo", sans-serif;')
    L.append('  --font-inter: "Archivo", sans-serif;  /* alias herdado do ASAP */')
    L.append('')
    L.append('  /* Cores institucionais, para uso direto */')
    for nome, valor in [('verde-escuro', MARCA['verde_escuro']), ('verde-claro', MARCA['verde_claro']),
                        ('ciano', MARCA['ciano']), ('laranja', MARCA['laranja']),
                        ('amarelo', MARCA['amarelo']), ('verde-educacao', MARCA['verde_educacao']),
                        ('violeta', MARCA['violeta']), ('azul-petroleo', MARCA['azul_petroleo']),
                        ('marrom', MARCA['marrom'])]:
        L.append(f'  --color-motriz-{nome}: {valor};')
    L.append('')
    for fam in ORDEM:
        rotulo = {'gray': 'neutra — ancorada nos dois cinzas do brandbook',
                  'blue': 'ação — ciano/verde escuro institucional',
                  'red': 'erro e atenção — laranja institucional',
                  'amber': 'aviso — amarelo institucional',
                  'green': 'sucesso — verde Educação',
                  'indigo': 'acento secundário — violeta'}.get(fam)
        L.append(f'  /* {fam}{" — " + rotulo if rotulo else ""} */')
        for d in DEGRAUS:
            L.append(f'  --color-{fam}-{d}: {ESCALAS[fam][d]};')
        L.append('')
    L.append('  /* Escala de texto do ASAP, preservada */')
    for nome, val in [('2xs', '11px'), ('xs', '13px')]:
        L.append(f'  --text-{nome}: calc({val} * var(--font-scale, 1));')
    for nome, val in [('sm', '0.875rem'), ('base', '1rem'), ('lg', '1.125rem'),
                      ('xl', '1.25rem'), ('2xl', '1.5rem'), ('3xl', '1.875rem')]:
        L.append(f'  --text-{nome}: calc({val} * var(--font-scale, 1));')
    L.append('}')
    return '\n'.join(L) + '\n'


# ---------------------------------------------------------------------------
# Saída 2: remapeamento dos hex literais do CSS escrito à mão
# ---------------------------------------------------------------------------
HEX = re.compile(r'#([0-9a-fA-F]{3,8})\b')
# Só mexe em valores de declaração (depois de `:`, antes de `;` ou `}`),
# nunca em seletor — senão `#ccc` como id viraria cor.
DECL = re.compile(r'(?<=:)([^;{}]*)(?=[;}])')


def _norm(h):
    """#abc -> #aabbcc; devolve (hex6, sufixo_alfa)."""
    c = h.lstrip('#')
    if len(c) == 3:
        return '#' + ''.join(ch * 2 for ch in c).lower(), ''
    if len(c) == 4:
        return '#' + ''.join(ch * 2 for ch in c[:3]).lower(), c[3] * 2
    if len(c) == 6:
        return '#' + c.lower(), ''
    if len(c) == 8:
        return '#' + c[:6].lower(), c[6:]
    return None, ''


def _degrau_mais_proximo(L):
    return min(DEGRAUS, key=lambda d: abs(L_TW[d] - L))


# Faixas de matiz → cor da marca. Explícito, não por vizinho mais próximo: o
# azul do CSS legado (H 242–264) é *cor de ação* — link, botão, seleção — e a
# Motriz responde a esse papel com o ciano, não com o violeta, que por matiz
# ficaria mais perto. Mesma decisão do mapeamento de tokens (docs/redmine/11).
FAIXAS = [
    ((15, 65),   MARCA['laranja']),         # vermelhos, laranjas, marrons
    ((65, 110),  MARCA['amarelo']),         # amarelos, ocres
    ((110, 170), MARCA['verde_educacao']),  # verdes
    ((170, 290), MARCA['ciano']),           # ciano, teal e TODOS os azuis: ação
    ((290, 375), MARCA['violeta']),         # roxos, magentas, rosas (375 = 15+360)
]
CROMA_MAX = 0.16   # teto de saturação; preserva vivacidade sem sair do registro


def _marca_por_matiz(H):
    Hn = H + 360 if H < 15 else H
    for (ini, fim), cor in FAIXAS:
        if ini <= Hn < fim:
            return cor
    return MARCA['ciano']


def remapear(hex_orig):
    """Neutro preserva luminosidade; cromático troca a matiz pela da marca."""
    base, alfa = _norm(hex_orig)
    if base is None:
        return None
    if base in ('#ffffff', '#000000'):
        return None                       # branco e preto puros ficam
    L, C, H = hex2oklch(base)
    if C < 0.025:                         # neutro
        novo = oklch2hex(L, C_NEUTRO, H_CINZA)
    else:
        _, _, Hm = hex2oklch(_marca_por_matiz(H))
        novo = oklch2hex(L, min(C, CROMA_MAX), Hm)
    return novo + alfa


GERADOS = {'motriz-theme.css'}   # saída do próprio script: nunca remapear
# Realce de sintaxe: 70 regras geradas pelo pygmentize dentro de legacy.css.
# São cores funcionais — precisam continuar distinguíveis entre si. Colapsá-las
# em cinco matizes da marca deixaria bloco de código ilegível (docs/redmine/08,
# armadilha 11). Ficam como estão.
PRESERVAR = ('syntaxhl',)


def aplicar_no_css(diretorio, escrever=True):
    arquivos = [a for a in sorted(Path(diretorio).glob('*.css'))
                if a.name not in GERADOS]
    mapa, por_arquivo, preservados = {}, {}, 0

    for arq in arquivos:
        linhas = arq.read_text(encoding='utf-8').split('\n')
        saida, n = [], 0
        pulando = False          # dentro de uma regra que não deve ser tocada
        seletor = ''

        for linha in linhas:
            if '{' in linha:
                seletor = linha.split('{')[0]
                pulando = any(p in seletor for p in PRESERVAR)
            if pulando:
                preservados += len(HEX.findall(linha))
                saida.append(linha)
                if '}' in linha:
                    pulando = False
                continue
            if '}' in linha:
                pulando = False

            def troca_decl(m):
                nonlocal n

                def troca_hex(h):
                    nonlocal n
                    orig = h.group(0)
                    novo = remapear(orig)
                    if novo is None:
                        return orig
                    base, _ = _norm(orig)
                    mapa[base] = novo[:7]
                    n += 1
                    return novo
                return HEX.sub(troca_hex, m.group(1))

            saida.append(DECL.sub(troca_decl, linha))

        if n:
            por_arquivo[arq.name] = n
            if escrever:
                arq.write_text('\n'.join(saida), encoding='utf-8')

    return mapa, por_arquivo, preservados


if __name__ == '__main__':
    falhas = valida()

    destino = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if falhas:
        print(f'{len(falhas)} par(es) abaixo de AA — nada foi escrito.')
        for nome, fg, bg, r, alvo in falhas:
            print(f'  {nome}: {r:.2f}:1 (precisa {alvo})')
        sys.exit(1)

    print(f'Logo: fundo {LOGO_BG}  hover {LOGO_BG_HOVER}')

    if destino is None:
        print('\nSem diretório de destino — apenas validação. '
              'Uso: python3 build_tailwind_theme.py <plugins/motriz_2/assets>')
        sys.exit(0)

    tema = destino / 'src' / 'motriz-theme.css'
    tema.write_text(bloco_theme(), encoding='utf-8')
    print(f'\n@theme escrito em {tema} ({len(tema.read_text())} bytes)')

    mapa, por_arquivo, preservados = aplicar_no_css(destino / 'src')
    print(f'\nHex remapeados no CSS legado: {len(mapa)} valores distintos')
    for nome, n in sorted(por_arquivo.items(), key=lambda kv: -kv[1]):
        print(f'  {n:4d}  {nome}')
    print(f'Preservados (realce de sintaxe): {preservados}')

    rel = destino / 'src' / 'REMAPEAMENTO-DE-COR.md'
    linhas = ['# Remapeamento de cor do CSS legado', '',
              'Gerado por `tools/build_tailwind_theme.py`. Cada hex literal do CSS',
              'escrito à mão foi remapeado: neutro preserva a luminosidade e adota a',
              'matiz fria do cinza da marca; cromático preserva a luminosidade e adota',
              'a matiz da família Motriz mais próxima.', '',
              '| Antes | Depois | Antes | Depois |', '|---|---|---|---|']
    itens = sorted(mapa.items())
    for i in range(0, len(itens), 2):
        par = itens[i:i + 2]
        celulas = []
        for a, b in par:
            celulas += [f'`{a}`', f'`{b}`']
        while len(celulas) < 4:
            celulas.append('')
        linhas.append('| ' + ' | '.join(celulas) + ' |')
    linhas += ['', f'Regras de realce de sintaxe preservadas: **{preservados} cores** '
               'em `.syntaxhl` — são funcionais, precisam continuar distinguíveis.',
               '', '## Ocorrências por arquivo', '', '| Arquivo | Substituições |', '|---|---:|']
    for nome, n in sorted(por_arquivo.items(), key=lambda kv: -kv[1]):
        linhas.append(f'| `{nome}` | {n} |')
    rel.write_text('\n'.join(linhas) + '\n', encoding='utf-8')
    print(f'Relatório em {rel}')
