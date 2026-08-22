# Motriz 2 — identidade Motriz sobre a estrutura do Redmine ASAP Theme

Plugin do Redmine que aplica a paleta, a tipografia e o logotipo da Motriz Digital
sobre a interface do [Redmine ASAP Theme](https://github.com/tantic/redmine_asap_theme).

**É um fork, não um tema.** Apesar do nome do upstream, o ASAP substitui o layout
base do Redmine e traz o próprio CSS — por isso vive em `plugins/`, não em `themes/`.

## Relação com o tema `motriz`

**Os dois são alternativas, não complementos.** O layout que este plugin instala
(`app/views/layouts/base.html.erb`) não carrega o `application.css` do Redmine, e
é justamente por esse link que o motor de temas serve o CSS do tema ativo. Com o
Motriz 2 ligado, o tema `motriz` deixa de pintar qualquer coisa.

| | tema `motriz` | plugin `motriz_2` |
|---|---|---|
| Onde | `themes/motriz/` | `plugins/motriz_2/` |
| O que muda | só CSS, sobre a interface original | layout, telas e navegação inteiros |
| Views do Redmine | intocadas | 69 sobrescritas |
| Banco | intocado | 6 migrations, 2 alteram tabelas do core |
| Desligar | trocar o tema no admin | desinstalar e reverter migrations |

Escolha um. O diagnóstico completo dessa fronteira está em
[`docs/redmine/13-asap-theme-como-base.md`](../../../docs/redmine/13-asap-theme-como-base.md).

## O que mudou em relação ao upstream

Estrutura, telas, JavaScript e funcionalidades são os do ASAP v2.4.0, sem alteração.
O que foi trocado:

| Área | Mudança |
|---|---|
| Identidade do plugin | id `motriz_2` (era `redmine_asap_theme`); 59 referências de asset e de `Setting` atualizadas |
| Paleta | as 22 escalas de cor do Tailwind redefinidas com as matizes do brandbook Motriz — recolore os 1.059 utilitários das views |
| CSS legado | 115 valores hex distintos remapeados; ver [`assets/src/REMAPEAMENTO-DE-COR.md`](assets/src/REMAPEAMENTO-DE-COR.md) |
| Realce de sintaxe | **preservado** — 71 cores de `.syntaxhl` ficaram intactas, senão bloco de código fica ilegível |
| Tipografia | Inter → **Archivo** (corpo) e **Bricolage Grotesque** (títulos), embutidas em `assets/fonts/` |
| Logotipo | slot quadrado 40×40 → altura fixa e largura automática, com o logotipo horizontal negativo sobre `#024b40` |
| Painel do login | `bg-blue-900` → `bg-blue-700` (`#024b40` exato) — o brandbook só admite o logotipo sobre verde escuro institucional ou branco |
| Favicon | ícone Motriz servido pelo próprio plugin, sem depender do tema selecionado |
| Ajustes padrão | cor do logo e wallpaper já vêm preenchidos; o upstream nasce vazio |
| Trava de versão | `requires_redmine version_or_higher: '6.0.0'` — o upstream não tinha nenhuma |

Cores geradas por `tools/build_tailwind_theme.py`, que **falha se algum par de
contraste cair abaixo de AA (4,5:1)**. São 22 pares verificados, incluindo modo escuro.

## Instalar

```bash
cp -r motriz_2 $REDMINE_ROOT/plugins/
cd $REDMINE_ROOT
bundle install                     # traz deface e letter_avatar
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Reiniciar o Redmine. Os ajustes ficam em Administração → Plugins → Motriz 2.

> As migrations `add_color_to_issues_statuses` e `add_color_to_trackers`
> **acrescentam colunas a tabelas do core**. Se um dia o `redmine_asap_theme`
> original for instalado ao lado, as duas colidem.

## Recompilar o CSS

O CSS servido (`assets/stylesheets/application.css`) é gerado. Depois de mexer em
qualquer `.erb` com classe nova, ou em qualquer `.css` de `assets/src/`:

```bash
cd assets
npm install                        # só na primeira vez, ou ao trocar de máquina
npx tailwindcss -i src/input.css -o stylesheets/application.css
```

Para regerar a paleta a partir do brandbook (sobrescreve `src/motriz-theme.css` e
reaplica o remapeamento no CSS legado — **rode sobre um `src/` limpo**):

```bash
cd ../../tools
python3 build_tailwind_theme.py ../redmine-7/plugins/motriz_2/assets
```

## Arquivos próprios deste fork

```
assets/src/motriz-theme.css        paleta — GERADO, não editar à mão
assets/src/motriz-fonts.css        @font-face de Archivo e Bricolage Grotesque
assets/src/motriz-marca.css        regras que a paleta não alcança (títulos, slot do logo)
assets/src/REMAPEAMENTO-DE-COR.md  relatório antes → depois do CSS legado
assets/fonts/                      4 .woff2 (SIL OFL 1.1)
assets/images/logo-motriz-digital-{negativo,positivo}.png
assets/images/favicon-motriz.svg
```

## O que ainda não foi verificado

- **Conferência visual.** O CSS compila e as checagens automáticas passam, mas
  nenhuma tela foi aberta num Redmine rodando.
- **Redmine 7.0.** O upstream declara compatibilidade testada até 6.1.x e diz que
  a 2.4.0 *"should work for Redmine 7.0 (need to be more tested)"*.
- Os wallpapers de login e as telas dos plugins Easy Gantt / Easy WBS não foram
  revisados quanto à cor.

## Licença e atribuição

Upstream: **Redmine ASAP Theme**, MIT © 2025 Tantic (DGAC/DSNA) —
<https://github.com/tantic/redmine_asap_theme>. O texto da licença está em
[`LICENSE`](LICENSE) e continua valendo para todo o código herdado, que é a
maior parte deste diretório.
