# Tema Motriz — Redmine 7.x

Identidade Motriz aplicada ao Redmine. Um único arquivo de estilo, sem plugin.

## Instalar

1. Copiar a pasta `motriz/` para `themes/` na raiz do Redmine (é onde ela já está)
2. **Reiniciar o Redmine** — a lista de temas é memoizada em `@@installed_themes`;
   sem restart o tema não aparece no dropdown
3. Administração → Configurações → Exibição → **Tema: Motriz** → Salvar

Em produção, se você usa precompilação de assets:

```bash
RAILS_ENV=production bin/rails assets:precompile
```

## O que tem aqui

```
themes/motriz/
├── stylesheets/application.css              o tema inteiro
├── images/logo-motriz-digital.svg           PLACEHOLDER — trocar
├── fonts/                                   Archivo + Bricolage Grotesque (SIL OFL)
│   ├── archivo-latin.woff2
│   ├── archivo-latin-ext.woff2
│   ├── bricolage-grotesque-latin.woff2
│   └── bricolage-grotesque-latin-ext.woff2
└── favicon/favicon.svg                      PLACEHOLDER — trocar
```

## Dois arquivos a substituir

**`images/logo-motriz-digital.svg`** — é um placeholder. As letras estão numa pilha
genérica com `textLength` travado, então a largura é igual em qualquer sistema, mas
não é a tipografia do logotipo. Substitua pelo **SVG oficial da Motriz Digital na
versão negativa** (para fundo verde escuro), mantendo o mesmo nome de arquivo:
nenhuma alteração de CSS é necessária.

**`favicon/favicon.svg`** — só a cor institucional, sem letra nem símbolo, para não
inventar uma marca. Substituir quando existir o ícone oficial.
Coloque **um arquivo só** nessa pasta: o Redmine usa `favicons.first` de um `Dir.glob`,
então dois arquivos deixam a escolha dependente da ordem alfabética.

## Como o tema funciona

O Redmine 7 consome cor por `var(--oc-*)` (paleta Open Color) em **341 lugares** do
`app/assets/stylesheets/application.css`. O tema redefine esses tokens com a paleta
Motriz e a interface acompanha. Só duas cores do chrome são hex fixo no core —
`nav.top-menu` e `#header` — e estão sobrescritas na seção 4 do CSS.

As cores de texto são derivações em OKLCH que **preservam a matiz** da cor
institucional de origem e alteram só a luminosidade, porque as cores vivas da marca
não atingem contraste AA sobre branco. Os 16 pares críticos são validados por
`tools/build_tokens.py` na raiz do projeto.

Documentação completa: `docs/redmine/00-INDEX.md`.

## O que ajustar por instalação

No fim do CSS, na seção **15. ADAPTAÇÕES**, há três blocos comentados:

- **Cor por projeto** — `body.project-<identificador>` dá acento por frente e por
  programa acelerador. Troque os identificadores pelos reais.
- **Situações com cor própria** — os ids de status variam por instalação. Descubra
  em Administração → Situações das tarefas.
- **Plugins com ícones antigos** — o Redmine 7 removeu os ícones raster; se algum
  plugin de terceiros não migrou, descomente o import de `legacy-icons-compat.css`.

## Decisões que valem revisão

- **A barra lateral vai para a esquerda.** O core usa `flex-direction: row-reverse`
  em `#main`, que a joga para a direita. Para voltar ao padrão, remova a seção 6.
- **O `#header h1` deixa de mostrar o nome do projeto** e passa a exibir
  "Gestão de Projetos" fixo. O nome do projeto continua visível no seletor de
  projeto, no topo à direita (o Redmine preenche o gatilho com `@project.name_was`).
- **Cores derivadas.** O brandbook proíbe cores fora da paleta institucional em peças
  de marca. Estados de interface (link, hover, erro) exigem tons que a paleta de 8
  cores não cobre com contraste legível. Todas as matizes são as originais.

## Armadilha de cascata

O layout carrega as folhas nesta ordem:

```erb
stylesheet_link_tag 'jquery/...', 'tribute-...', 'application', 'dropdown', 'responsive'
```

O tema ocupa o lugar de `application`, então **`responsive.css` carrega depois e ganha
nos empates de especificidade**. Ele traz três cores próprias em hex fixo
(`#628db6` no `#header` mobile, `#3e5b76` no `.flyout-menu`, `#506a83` nas bordas).
Por isso os seletores da seção 14 levam um `body` na frente — sem isso o cabeçalho
mobile volta a ficar azul.
