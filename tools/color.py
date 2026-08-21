"""Conversao sRGB <-> OKLCH e contraste WCAG. Usado para derivar os tokens do tema Motriz."""
import math

def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16)/255 for i in (0, 2, 4))

def rgb2hex(r, g, b):
    f = lambda c: max(0, min(255, round(c*255)))
    return '#%02x%02x%02x' % (f(r), f(g), f(b))

def _lin(c):  return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4
def _srgb(c): return c*12.92 if c <= 0.0031308 else 1.055*(c**(1/2.4))-0.055

def rgb2oklab(r, g, b):
    r, g, b = _lin(r), _lin(g), _lin(b)
    l = 0.4122214708*r + 0.5363325363*g + 0.0514459929*b
    m = 0.2119034982*r + 0.6806995451*g + 0.1073969566*b
    s = 0.0883024619*r + 0.2817188376*g + 0.6299787005*b
    l, m, s = l**(1/3), m**(1/3), s**(1/3)
    return (0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
            1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
            0.0259040371*l + 0.7827717662*m - 0.8086757660*s)

def oklab2rgb(L, a, bb):
    l = (L + 0.3963377774*a + 0.2158037573*bb)**3
    m = (L - 0.1055613458*a - 0.0638541728*bb)**3
    s = (L - 0.0894841775*a - 1.2914855480*bb)**3
    return (_srgb( 4.0767416621*l - 3.3077115913*m + 0.2309699292*s),
            _srgb(-1.2684380046*l + 2.6097574011*m - 0.3413193965*s),
            _srgb(-0.0041960863*l - 0.7034186147*m + 1.7076147010*s))

def hex2oklch(h):
    L, a, b = rgb2oklab(*hex2rgb(h))
    return (L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360)

def oklch2hex(L, C, H):
    a = C*math.cos(math.radians(H)); b = C*math.sin(math.radians(H))
    return rgb2hex(*oklab2rgb(L, a, b))

def lum(h):
    r, g, b = hex2rgb(h)
    return 0.2126*_lin(r) + 0.7152*_lin(g) + 0.0722*_lin(b)

def contrast(f, b):
    a, c = lum(f), lum(b)
    hi, lo = max(a, c), min(a, c)
    return (hi+0.05)/(lo+0.05)

def darken_to(h, target, bg='#ffffff'):
    """Escurece mantendo matiz e croma ate atingir o contraste alvo."""
    L, C, H = hex2oklch(h)
    best = h
    for i in range(1, 1001):
        cand = oklch2hex(L*(1 - i/1000), C, H)
        best = cand
        if contrast(cand, bg) >= target:
            return cand
    return best
