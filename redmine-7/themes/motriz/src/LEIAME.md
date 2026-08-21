# Fontes do tema

O Redmine **não serve** este diretório: `Redmine::AssetPath#asset_paths` exclui
`src/` explicitamente. É o lugar para arquivos de origem que não devem ir para a web.

- `digital-original.png` — logotipo Motriz Digital como recebido (2000×1414, fundo
  transparente, `#00463c` + `#46c88c`).

Os arquivos servidos em `images/` são derivados dele por `tools/gerar-logo.py`:

- `logo-motriz-digital-negativo.png` — recortado e recolorido para fundo escuro
  (escuro → branco, claro → `#4dcb93` do brandbook). É o usado no masthead.
- `logo-motriz-digital-positivo.png` — só recortado, cores originais, para fundo claro.

Se receber a versão negativa **oficial**, substitua o arquivo em `images/`
mantendo o nome — o CSS dimensiona pela altura, então largura diferente não quebra.
