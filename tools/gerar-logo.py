#!/usr/bin/env python3
"""
Deriva as versões servidas do logotipo a partir do original em
themes/motriz/src/digital-original.png.

O original é positivo (motriz em verde escuro) e tem margem transparente larga.
Este script recorta a margem e gera duas variantes em themes/motriz/images/:

  logo-motriz-digital-negativo.png  para fundo escuro — escuro vira branco e o
                                    claro é normalizado para #4dcb93 do brandbook
  logo-motriz-digital-positivo.png  só recortado, cores originais, para fundo claro

O recolorir preserva o canal alfa, então o antialiasing das bordas continua
intacto: nenhuma forma é redesenhada.

Uso: python3 tools/gerar-logo.py
"""
import pathlib
from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
TEMA = RAIZ / "redmine-7" / "themes" / "motriz"
ORIGEM = TEMA / "src" / "digital-original.png"
DESTINO = TEMA / "images"
LARGURA = 480          # ~3x o tamanho exibido; suficiente para telas retina

ESCURO = (0, 70, 60)       # #00463c — "motriz" no arquivo original
CLARO = (70, 200, 140)     # #46c88c — "digital" no arquivo original
BRANCO = (255, 255, 255)
VERDE_CLARO = (77, 203, 147)   # #4dcb93 — verde claro institucional


def recortar(im):
    px = im.load()
    w, h = im.size
    xs = [x for x in range(w) for y in range(0, h, 2) if px[x, y][3] > 20]
    ys = [y for y in range(0, h, 2) for x in range(0, w, 3) if px[x, y][3] > 20]
    return im.crop((min(xs), min(ys), max(xs) + 1, max(ys) + 1))


def negativar(im):
    out = im.copy()
    q = out.load()
    for x in range(out.size[0]):
        for y in range(out.size[1]):
            r, g, b, a = q[x, y]
            if a == 0:
                continue
            perto_do_escuro = (
                (r - ESCURO[0]) ** 2 + (g - ESCURO[1]) ** 2 + (b - ESCURO[2]) ** 2
                < (r - CLARO[0]) ** 2 + (g - CLARO[1]) ** 2 + (b - CLARO[2]) ** 2
            )
            q[x, y] = (BRANCO if perto_do_escuro else VERDE_CLARO) + (a,)
    return out


def redimensionar(im):
    return im.resize((LARGURA, round(im.size[1] * LARGURA / im.size[0])), Image.LANCZOS)


def main():
    recortado = recortar(Image.open(ORIGEM).convert("RGBA"))
    for nome, img in (("negativo", negativar(recortado)), ("positivo", recortado)):
        destino = DESTINO / f"logo-motriz-digital-{nome}.png"
        redimensionar(img).save(destino, optimize=True)
        print(f"  {destino.name}: {destino.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
