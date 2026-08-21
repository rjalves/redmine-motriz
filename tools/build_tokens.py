"""Deriva os tokens Open Color do tema Motriz a partir da paleta do brandbook e valida contraste."""
from color import hex2oklch, oklch2hex, contrast, darken_to

MARCA = {
    'verde_escuro': '#024b40', 'verde_claro': '#4dcb93', 'ciano': '#26c1c8',
    'laranja': '#f36d36', 'amarelo': '#ffc033', 'verde_educacao': '#5ba046',
    'marrom': '#4a1702', 'violeta': '#5c2e91', 'azul_petroleo': '#253b61',
    'branco': '#ffffff', 'cinza_claro': '#dfe1e3', 'cinza_escuro': '#6d6e71',
}

# --- Escala neutra: ancorada nos dois cinzas da marca (gray-3 e gray-6) ---
# Matiz/croma copiados do proprio cinza da marca (levemente frio, quase neutro).
_, C_N, H_N = hex2oklch(MARCA['cinza_claro'])
C_N = 0.004
L_RAMP = {0:0.980, 1:0.960, 2:0.938, 3:0.909, 4:0.845, 5:0.700, 6:0.538, 7:0.428, 8:0.340, 9:0.255}
gray = {i: oklch2hex(L, C_N, H_N) for i, L in L_RAMP.items()}
gray[3] = MARCA['cinza_claro']    # ancora exata da marca
gray[6] = MARCA['cinza_escuro']   # ancora exata da marca

def tint(base, L, C):
    _, _, H = hex2oklch(base)
    return oklch2hex(L, C, H)

TOKENS = {
    # Acao / links -- matiz do ciano institucional, escurecida para AA folgado
    'blue-9': darken_to(MARCA['ciano'], 5.5),
    'blue-7': MARCA['verde_escuro'],
    'blue-0': tint(MARCA['ciano'], 0.965, 0.020),
    # Atencao / hover / atraso -- matiz do laranja institucional
    'red-9': darken_to(MARCA['laranja'], 4.5),
    'red-8': darken_to(MARCA['laranja'], 5.5),
    # Sucesso -- matiz do verde Educacao
    'green-7': darken_to(MARCA['verde_educacao'], 4.5),
    'green-8': darken_to(MARCA['verde_educacao'], 5.0),
    'green-9': darken_to(MARCA['verde_educacao'], 7.0),
    # Aviso -- matiz do amarelo institucional
    'yellow-9': darken_to(MARCA['amarelo'], 4.5),
    'yellow-0': tint(MARCA['amarelo'], 0.972, 0.030),
    'yellow-4': darken_to(MARCA['amarelo'], 4.5),
    # Selecao / menu de projeto -- matiz institucional
    'indigo-0': tint(MARCA['verde_escuro'], 0.968, 0.018),
    'indigo-1': tint(MARCA['verde_escuro'], 0.945, 0.028),
    'indigo-5': darken_to(MARCA['verde_claro'], 5.0),
    'indigo-9': MARCA['verde_escuro'],
    'cyan-6': darken_to(MARCA['ciano'], 4.8),
    'grape-7': darken_to(MARCA['violeta'], 5.0),
}
for i, h in gray.items():
    TOKENS[f'gray-{i}'] = h

CHECKS = [
    ('link sobre fundo branco',        TOKENS['blue-9'], '#ffffff', 4.5),
    ('hover/atraso sobre branco',      TOKENS['red-9'],  '#ffffff', 4.5),
    ('texto branco sobre badge-private','#ffffff', TOKENS['red-8'],  4.5),
    ('texto branco sobre avatar verde', '#ffffff', TOKENS['green-7'], 4.5),
    ('texto branco sobre avatar azul',  '#ffffff', TOKENS['blue-7'],  4.5),
    ('texto branco sobre avatar ciano', '#ffffff', TOKENS['cyan-6'],  4.5),
    ('texto branco sobre avatar uva',   '#ffffff', TOKENS['grape-7'], 4.5),
    ('texto branco sobre badge-count',  '#ffffff', TOKENS['indigo-5'],4.5),
    ('aviso sobre branco',             TOKENS['yellow-9'],'#ffffff', 4.5),
    ('texto secundario (gray-6)',      TOKENS['gray-6'], '#ffffff', 4.5),
    ('texto principal (gray-9)',       TOKENS['gray-9'], '#ffffff', 4.5),
    ('titulos verde institucional',    MARCA['verde_escuro'], '#ffffff', 4.5),
    ('selecionado sidebar',            TOKENS['indigo-9'], TOKENS['indigo-1'], 4.5),
    ('branco sobre masthead',          '#ffffff', MARCA['verde_escuro'], 4.5),
    ('verde claro sobre masthead',     MARCA['verde_claro'], MARCA['verde_escuro'], 4.5),
    ('borda (gray-4) sobre branco',    TOKENS['gray-4'], '#ffffff', 1.5),
]

if __name__ == '__main__':
    print('=== TOKENS DERIVADOS ===')
    for k in sorted(TOKENS, key=lambda s: (s.split('-')[0], int(s.split('-')[1]))):
        print(f'  --oc-{k:10} {TOKENS[k]}')
    print('\n=== VALIDACAO DE CONTRASTE ===')
    falhas = 0
    for nome, fg, bg, alvo in CHECKS:
        r = contrast(fg, bg); ok = r >= alvo
        falhas += (not ok)
        print(f'  {"OK " if ok else "FALHA"}  {nome:34} {r:6.2f}:1  (min {alvo})')
    print(f'\n{"TODOS OS PARES PASSAM" if not falhas else str(falhas)+" FALHA(S)"}')
