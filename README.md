# redmine-motriz

Redmine 7.0.0 com o tema visual da **Motriz Digital**.

## Layout

```
redmine-7/            Redmine 7.0.0 — base intocada (commit 1)
  themes/motriz/      o tema (único arquivo customizado dentro do Redmine)
docs/redmine/         base de conhecimento: como o Redmine carrega temas, tokens,
                      seletores, armadilhas — extraída do código-fonte, não da wiki
design/               artboards do canvas de design + capturas de validação
tools/                gerador de cor (valida contraste AA) e scripts de execução local
```

## Subir localmente

O Redmine 7 exige Ruby >= 3.2. O script usa a imagem oficial `redmine:7.0.0` com o
tema montado, popula dados de demonstração e deixa em <http://localhost:3001>:

```bash
tools/dev/subir-local.sh          # admin / motriz123456
docker restart redmine-motriz     # depois de editar o CSS do tema
docker rm -f redmine-motriz       # derrubar
```

## Design

Telas aprovadas no canvas: <https://claude.ai/code/artifact/a80afa4d-459b-46bd-be9c-af8dea28f2c4>

As fontes das artboards estão em `design/` (`build.py` monta os `.dc.html` a partir de
`_base.css` + `frag_*.html`). Capturas da validação contra o Redmine rodando estão em
`design/validacao/`.

## Instalar o tema num Redmine existente

1. Copiar `redmine-7/themes/motriz/` para `themes/` do Redmine de destino
2. Reiniciar a aplicação (a lista de temas é memoizada)
3. Administração → Configurações → Exibição → **Tema: Motriz** → Salvar

Detalhes e o que ajustar por instalação: [`redmine-7/themes/motriz/README.md`](redmine-7/themes/motriz/README.md).

## Pendências conhecidas

- `themes/motriz/images/logo-motriz-digital.svg` é **placeholder** — substituir pelo
  SVG oficial da Motriz Digital na versão negativa, mantendo o nome do arquivo
- `themes/motriz/favicon/favicon.svg` é **placeholder**
- Mapear os identificadores reais de projeto e os ids de situação na seção 15 do CSS
