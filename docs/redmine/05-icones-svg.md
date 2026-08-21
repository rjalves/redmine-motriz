# 05 — Ícones SVG (Redmine 6+/7)

Fonte: `reference/redmine-icons_helper.rb`, `reference/redmine-lib-themes.rb`,
`reference/redmine7-icons.svg`, `reference/redmine7-icon-names.txt`.

## O sistema

O Redmine 7 removeu os ícones raster e usa um **sprite SVG único** com 117 símbolos.
Cada ícone é renderizado assim:

```ruby
content_tag(:svg,
  content_tag(:use, '', { 'href' => "#{asset_path(sprite)}#icon--#{icon_name}" }),
  class: css_classes, aria: { hidden: true })
```

HTML resultante:

```html
<svg class="s18 icon-svg" aria-hidden="true">
  <use href="/assets/icons-<digest>.svg#icon--edit"></use>
</svg>
```

Convenções:
- Os símbolos têm id no formato **`icon--<nome>`**
- Classe de tamanho `s<N>`, padrão `s18` (`DEFAULT_ICON_SIZE = "18"`)
- Classe base `icon-svg`; variante preenchida adiciona `icon-svg-filled`
- `icon-rtl` quando o ícone deve espelhar em RTL

## Como o tema sobrescreve ícones

Este é o trecho decisivo (`icons_helper.rb`):

```ruby
def sprite_source(icon_name, sprite: DEFAULT_SPRITE, plugin: nil)
  if plugin
    "plugin_assets/#{plugin}/#{sprite}.svg"
  elsif current_theme && current_theme.icons(sprite).include?(icon_name)
    current_theme.image_path("#{sprite}.svg")
  else
    "#{sprite}.svg"
  end
end
```

E do lado do tema (`themes.rb`):

```ruby
def icons(sprite)
  asset = Rails.application.assets.load_path.find(image_path("#{sprite}.svg"))
  return [] unless asset
  ActionController::Base.cache_store.fetch("theme-icons/#{id}/#{sprite}/#{asset.digest}") do
    asset.content.scan(/id=['"]icon--([^'"]+)['"]/).flatten
  end
end
```

O que isso significa, e é excelente:

1. Coloque um **`images/icons.svg` parcial** no seu tema.
2. O Redmine lê os ids `icon--*` presentes nele.
3. **Fallback é por ícone, não por arquivo.** Ícone presente no seu sprite → usa o
   seu; ausente → usa o do core.

Ou seja, **você pode sobrescrever 3 ícones e herdar os outros 114.** Não é
necessário copiar o sprite inteiro.

### Sprite mínimo de tema

```xml
<svg xmlns="http://www.w3.org/2000/svg" style="display:none">
  <symbol id="icon--edit" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round">
    <path d="M4 20h4L18.5 9.5a2.1 2.1 0 0 0-3-3L5 17v3z"/>
  </symbol>
  <symbol id="icon--add" viewBox="0 0 24 24" fill="none"
          stroke="currentColor" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 5v14M5 12h14"/>
  </symbol>
</svg>
```

Regras para o desenho funcionar com o CSS do Redmine:
- Use `<symbol>` com `id="icon--<nome>"` — o scan é literalmente esse regex
- Defina `viewBox` (o core não define largura/altura no `<use>`)
- Desenhe em **contorno** com `fill="none"` e `stroke="currentColor"`;
  o CSS do core controla `stroke`/`fill` (ver abaixo)
- Grid de 24×24 é o do sprite oficial

O cache é chaveado pelo `asset.digest` — ao trocar o SVG o digest muda e o cache
invalida sozinho. Mas a **lista de temas** continua memoizada: reinicie ao adicionar
o `icons.svg` pela primeira vez.

## Como recolorir ícones

O core colore por `stroke` (contorno) e `fill` (preenchido):

```css
a.icon .icon-svg,
a.icon-only .icon-svg,
span.icon-actions .icon-svg {
  stroke: var(--oc-blue-9);
  fill: none;
}
a.icon:hover .icon-svg,
a.icon-only:hover .icon-svg,
span.icon-actions:hover .icon-svg {
  stroke: var(--oc-red-9);
}
a.icon .icon-svg-filled,
a.icon-only .icon-svg-filled {
  stroke: none;
  fill: var(--oc-blue-9);
}
a.icon:hover .icon-svg-filled,
a.icon-only:hover .icon-svg-filled {
  stroke: none;
  fill: var(--oc-red-9);
}
.icon-ok    svg.icon-svg { stroke: var(--oc-green-8); }
.icon-error svg.icon-svg { stroke: var(--oc-red-8); }
#sidebar a.selected svg.icon-svg { stroke: var(--oc-indigo-9) !important; }
```

Portanto **redefinir `--oc-blue-9` e `--oc-red-9` recolore todos os ícones de ação**
de uma vez — sem tocar em SVG. É o caminho mais barato.

Atenção ao `!important` em `#sidebar a.selected svg.icon-svg`: para mudar essa cor
sem redefinir `--oc-indigo-9`, seu seletor também precisa de `!important`.

## Os 117 ícones disponíveis

Lista completa em `reference/redmine7-icon-names.txt`. Amostra:

```
3-bullets add alert-circle angle-down angle-left angle-right angle-up
application-gzip application-javascript application-pdf application-zip apps
arrow-narrow-left arrow-narrow-right arrow-right attachment bookmark-add
bookmark-delete bookmarked bulb bullet-end bullet-go bullet-go-end cancel
changeset checked chevrons-left chevrons-right circle-dot-filled circle-minus
clear-query close comment comments copy copy-link copy-pre-content custom-fields
del document download edit email email-disabled fav file file-music
file-type-docx file-type-ppt file-type-xls folder folder-open group help
history hourglass import issue issue-closed issue-edit ...
```

Consulte o arquivo para os 117.

## Ícones por tipo MIME

`ICON_MIME_TYPES` mapeia content-types para ícones (`application-pdf`, `photo`,
`movie`, `file-music`, `text-x-ruby`, `file-type-docx`…). Se você sobrescrever esses
nomes no seu sprite, os anexos mudam de aparência automaticamente.

## Compatibilidade com plugins antigos

`legacy-icons-compat.css` existe para plugins que ainda usam os ícones raster
removidos no 7.0:

```css
@import url('/legacy-icons-compat.css');
```

Se o Redmine alvo tem plugins de terceiros não migrados, considere incluir esse
import no tema — senão ícones de plugin somem. Cópia em
`reference/redmine7-legacy-icons-compat.css`.

## Redmine ≤ 5.x

Nada disso existe. Os ícones são PNG referenciados por `background-image` em classes
`.icon-*`. Para trocá-los, sobrescreva o `background-image` apontando para
`../images/<arquivo>.png` do seu tema.
