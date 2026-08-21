"""
Deriva TODOS os tokens Open Color que o Redmine 7 usa, a partir das matizes do
brandbook Motriz, e valida contraste. Rode: python3 build_tokens.py
"""
from color import hex2oklch, oklch2hex, contrast, darken_to

MARCA = {
    'verde_escuro': '#024b40', 'verde_claro': '#4dcb93', 'ciano': '#26c1c8',
    'laranja': '#f36d36', 'amarelo': '#ffc033', 'verde_educacao': '#5ba046',
    'marrom': '#4a1702', 'violeta': '#5c2e91', 'azul_petroleo': '#253b61',
    'branco': '#ffffff', 'cinza_claro': '#dfe1e3', 'cinza_escuro': '#6d6e71',
}

# Luminosidade de cada degrau, espelhando a curva do Open Color.
L_ESCALA = {0: .972, 1: .944, 2: .906, 3: .858, 4: .800, 5: .735,
            6: .668, 7: .590, 8: .512, 9: .430}
# Croma por degrau: baixo nos claros (fundos), cheio no meio, contido nos escuros.
C_ESCALA = {0: .020, 1: .038, 2: .062, 3: .090, 4: .115, 5: .132,
            6: .140, 7: .132, 8: .116, 9: .098}

def escala(base_hex, ajuste_L=0.0):
    """Gera os 10 degraus preservando a matiz exata da cor de origem."""
    _, _, H = hex2oklch(base_hex)
    return {i: oklch2hex(min(.99, L_ESCALA[i] + ajuste_L), C_ESCALA[i], H) for i in range(10)}

# --- escala neutra: ancorada nos dois cinzas do brandbook -----------------------
_, _, H_CINZA = hex2oklch(MARCA['cinza_claro'])
L_NEUTRO = {0:.980, 1:.960, 2:.938, 3:.909, 4:.845, 5:.700, 6:.538, 7:.428, 8:.340, 9:.255}
gray = {i: oklch2hex(L, 0.004, H_CINZA) for i, L in L_NEUTRO.items()}
gray[3] = MARCA['cinza_claro']
gray[6] = MARCA['cinza_escuro']

# --- famílias cromáticas, cada uma ancorada numa cor da marca -------------------
FAMILIAS = {
    'blue':   MARCA['ciano'],            # ação: links, ícones, seleção
    'cyan':   MARCA['ciano'],
    'indigo': MARCA['verde_escuro'],     # menu de projeto, item ativo
    'teal':   MARCA['verde_escuro'],
    'green':  MARCA['verde_educacao'],   # sucesso, progresso
    'lime':   MARCA['verde_claro'],
    'yellow': MARCA['amarelo'],          # aviso
    'orange': MARCA['laranja'],          # atenção, destaque
    'red':    MARCA['laranja'],          # erro (a marca não tem vermelho)
    'pink':   MARCA['laranja'],          # o core usa pink-9 como texto de aviso
    'grape':  MARCA['violeta'],
    'violet': MARCA['violeta'],
}
TOKENS = {}
for fam, base in FAMILIAS.items():
    for i, hexa in escala(base).items():
        TOKENS[f'{fam}-{i}'] = hexa
for i, hexa in gray.items():
    TOKENS[f'gray-{i}'] = hexa

# --- ajustes deliberados, onde o papel no Redmine pede valor específico ---------
TOKENS.update({
    'gray-9-rgb':  '33, 35, 37',
    'blue-9':  darken_to(MARCA['ciano'], 5.5),          # links — 5,54:1
    'blue-7':  MARCA['verde_escuro'],                   # fundo de hover, avatar
    'red-9':   darken_to(MARCA['laranja'], 4.5),        # hover, atraso, obrigatório
    'red-8':   darken_to(MARCA['laranja'], 5.5),        # badge privado, erro
    'pink-9':  darken_to(MARCA['laranja'], 5.5),        # texto de aviso
    'orange-9':darken_to(MARCA['laranja'], 5.5),
    'green-7': darken_to(MARCA['verde_educacao'], 4.5), # progresso, avatar
    'green-8': darken_to(MARCA['verde_educacao'], 5.0),
    'green-9': darken_to(MARCA['verde_educacao'], 7.0),
    'yellow-9':darken_to(MARCA['amarelo'], 4.5),
    'yellow-4':darken_to(MARCA['amarelo'], 4.5),
    'indigo-9':MARCA['verde_escuro'],
    'indigo-5':darken_to(MARCA['verde_claro'], 5.0),    # badge-count
    'grape-7': MARCA['violeta'],
    'cyan-6':  darken_to(MARCA['ciano'], 4.8),
    # --oc-yellow-0 NÃO é aviso: pinta hover de linha, painel da tarefa e TOC do wiki
    'yellow-0': '#f1f9f6',
    # #login-form usa --oc-orange-1; queremos um cartão claro, não bege
    'orange-1': '#ffffff',
})

CHECKS = [
    ('link sobre branco',              TOKENS['blue-9'], '#ffffff', 4.5),
    ('hover/atraso sobre branco',      TOKENS['red-9'],  '#ffffff', 4.5),
    ('branco sobre badge privado',     '#ffffff', TOKENS['red-8'],  4.5),
    ('branco sobre avatar verde',      '#ffffff', TOKENS['green-7'], 4.5),
    ('branco sobre avatar escuro',     '#ffffff', TOKENS['blue-7'],  4.5),
    ('branco sobre avatar ciano',      '#ffffff', TOKENS['cyan-6'],  4.5),
    ('branco sobre avatar uva',        '#ffffff', TOKENS['grape-7'], 4.5),
    ('branco sobre badge-count',       '#ffffff', TOKENS['indigo-5'],4.5),
    ('aviso sobre branco',             TOKENS['yellow-9'],'#ffffff', 4.5),
    ('texto secundário',               TOKENS['gray-6'], '#ffffff', 4.5),
    ('texto principal',                TOKENS['gray-9'], '#ffffff', 4.5),
    ('títulos institucionais',         MARCA['verde_escuro'], '#ffffff', 4.5),
    ('selecionado na barra lateral',   TOKENS['indigo-9'], TOKENS['indigo-1'], 4.5),
    ('branco sobre masthead',          '#ffffff', MARCA['verde_escuro'], 4.5),
    ('verde claro sobre masthead',     MARCA['verde_claro'], MARCA['verde_escuro'], 4.5),
    # Os três pares de mensagem, exatamente como o core os monta (application.css ~1508)
    ('flash erro: pink-9 / red-1',     TOKENS['pink-9'],  TOKENS['red-1'],    4.5),
    ('flash aviso: pink-9 / yellow-1', TOKENS['pink-9'],  TOKENS['yellow-1'], 4.5),
    ('flash sucesso: green-9 / green-1', TOKENS['green-9'], TOKENS['green-1'], 4.5),
    ('.nodata: pink-9 / yellow-1',     TOKENS['pink-9'],  TOKENS['yellow-1'], 4.5),
]

def css():
    linhas = []
    for k in sorted(TOKENS, key=lambda s: (s.split('-')[0], s.split('-')[1])):
        linhas.append(f"  --oc-{k}: {TOKENS[k]};")
    return "\n".join(linhas)

if __name__ == '__main__':
    print(f"=== {len(TOKENS)} TOKENS ===\n{css()}\n")
    print("=== CONTRASTE ===")
    falhas = 0
    for nome, fg, bg, alvo in CHECKS:
        r = contrast(fg, bg); ok = r >= alvo; falhas += (not ok)
        print(f"  {'OK   ' if ok else 'FALHA'} {nome:34} {r:6.2f}:1 (min {alvo})")
    print(f"\n{'TODOS OS PARES PASSAM' if not falhas else str(falhas)+' FALHA(S)'}")
