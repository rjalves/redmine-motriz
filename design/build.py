"""Monta os arquivos .dc.html das artboards a partir dos fragmentos + tokens compartilhados."""
import pathlib
BASE = pathlib.Path(__file__).parent
css  = (BASE/"_base.css").read_text()
logo = (BASE/"_logo.html").read_text().strip()

TPL = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;500;600;700;800&family=Bricolage+Grotesque:opsz,wght@12..96,400;12..96,500;12..96,600&family=Poppins:wght@300;400;600&display=swap">
  <style>
%(css)s
%(extra)s
  </style>
</helmet>
%(body)s
</x-dc>
<script data-dc-script data-props='{"$preview":{"width":%(w)d,"height":%(h)d}}'>
class Component extends DCLogic {
  renderVals() { return {}; }
}
</script>
</body>
</html>
"""

ARTBOARDS = [
    ("Main",     1440,  900, ""),
    ("Tarefa",   1440, 1400, ""),
    ("Sistema",  1240, 1820, ""),
    ("Frentes",  1440,  820, ""),
]

for name, w, h, extra in ARTBOARDS:
    frag = BASE/f"frag_{name.lower()}.html"
    if not frag.exists():
        print(f"  (pulando {name}: fragmento ausente)"); continue
    body = frag.read_text().replace("<!--LOGO-->", logo)
    out = BASE/f"{name}.dc.html"
    out.write_text(TPL % dict(css=css.rstrip(), extra=extra, body=body.rstrip(), w=w, h=h))
    print(f"  {out.name}  {len(out.read_text())//1024} KB  ({w}x{h})")
