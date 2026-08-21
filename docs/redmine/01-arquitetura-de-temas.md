# 01 — Arquitetura de temas do Redmine

Fonte: `lib/redmine/themes.rb` (cópia em `reference/redmine-lib-themes.rb`).
Este arquivo é a autoridade — o que não está nele, o Redmine não faz.

## O contrato mínimo

O Redmine varre os diretórios de tema assim:

```ruby
def self.scan_themes
  dirs = Dir.glob(["#{Rails.root}/app/assets/themes/*", "#{Rails.root}/themes/*"]).select do |f|
    # A theme should at least override application.css
    File.directory?(f) && File.exist?("#{f}/stylesheets/application.css")
  end
  dirs.collect {|dir| Theme.new(dir)}.sort
end
```

Consequências diretas:

1. **São dois locais válidos** no Redmine 6+/7: `app/assets/themes/*` (onde vivem os
   temas nativos) e `themes/*` na raiz (onde vão os seus). Ambos funcionam.
2. **`stylesheets/application.css` é obrigatório.** Sem esse arquivo exato, o
   diretório é ignorado silenciosamente e o tema nem aparece no dropdown.
3. A varredura é **memoizada** em `@@installed_themes`. Um tema novo só aparece
   após `Redmine::Themes.rescan` ou, na prática, **reiniciar a aplicação**.

## Identidade do tema

```ruby
@dir  = File.basename(path)   # nome do diretório
@name = @dir.humanize         # rótulo no dropdown do admin
def id; dir end               # o id salvo em Setting.ui_theme
```

- O **nome do diretório é o id**. Renomear a pasta quebra a configuração salva.
- O rótulo exibido é `dir.humanize`: `motriz_dark` → **"Motriz dark"**.
  Não há como definir um nome bonito separado — escolha o nome da pasta pensando nisso.
- A ordenação no dropdown é por `name` (`<=>` compara `name`).

## Diretórios de asset reconhecidos

```ruby
def asset_paths
  base_dir = Pathname.new(path)
  paths = base_dir.children.select do |child|
    child.directory? &&
      child.basename.to_s != 'src' &&
      !child.basename.to_s.start_with?('.')
  end
  Redmine::AssetPath.new(base_dir, paths, asset_prefix)
end
```

**Qualquer subdiretório vira asset path**, exceto:
- `src/` — explicitamente excluído. É a convenção oficial para fontes de build
  (Sass, PostCSS, SVGs originais). Use `src/` para tudo que não deve ser servido.
- Diretórios começando com `.`

Ou seja, além de `stylesheets/`, `javascripts/`, `images/` e `favicon/`, você pode
criar `fonts/` e ele será servido normalmente.

O prefixo público é:

```ruby
def asset_prefix; "themes/#{dir}/" end
```

### O subdiretório some do caminho lógico

`AssetPath#each_file` calcula `relative_path` **a partir de cada subdiretório**, não
da raiz do tema:

```ruby
relative_path = file.relative_path_from(path).to_s      # path = .../motriz/images
logical_path  = File.join(prefix, relative_path)        # themes/motriz/logo.svg
```

Ou seja, `themes/motriz/images/logo.svg` vira o caminho lógico
`themes/motriz/logo.svg` — **sem o segmento `images/`**. Consequências:

- Nomes de arquivo precisam ser únicos **entre** os subdiretórios (`images/x.svg` e
  `fonts/x.svg` colidiriam).
- No CSS você continua escrevendo o caminho relativo natural — `url(../images/logo.svg)`,
  `url(../fonts/fonte.woff2)`. `Redmine::Asset#convert_path` reescreve `../images` e
  `../fonts` para o caminho lógico antes de servir. É exatamente para isso que o
  mapa de transição existe.

## Assets que o Redmine procura por convenção

| Método | Glob | Uso |
|---|---|---|
| `stylesheets` | `<tema>/stylesheets/*.css` | `application.css` é o obrigatório |
| `javascripts` | `<tema>/javascripts/*.js` | só `theme.js` é auto-carregado |
| `images` | `<tema>/images/*` | qualquer arquivo; `icons.svg` tem tratamento especial |
| `favicons` | `<tema>/favicon/*` | **o primeiro arquivo do diretório** vira o favicon |

Sobre o favicon — `favicon` é `favicons.first`, e `favicons` é um `Dir.glob`.
**Não coloque mais de um arquivo em `favicon/`**: a escolha vira dependente da
ordem do glob (na prática alfabética), o que é frágil.

## Como o CSS e o JS entram na página

O layout (`app/views/layouts/base.html.erb`) chama:

```erb
<%= stylesheet_link_tag 'jquery/jquery-ui-1.13.2', 'tribute-5.1.3', 'application', 'dropdown', 'responsive', :media => 'all' %>
<%= javascript_importmap_tags %>
<%= javascript_heads %>
<%= heads_for_theme %>
```

E o helper:

```ruby
def heads_for_theme
  if current_theme && current_theme.javascripts.include?('theme')
    javascript_include_tag current_theme.javascript_path('theme')
  end
end
```

Ponto crítico: **o arquivo precisa se chamar exatamente `theme.js`.**
`javascripts/main.js` ou `javascripts/custom.js` nunca são carregados sozinhos.

Sobre o `application` no `stylesheet_link_tag`: quando um tema está ativo, o Rails
resolve `application.css` **para o do tema** (via asset path do tema, que tem
precedência). É por isso que o `@import` do CSS core no topo do seu arquivo é
necessário — senão você perde todo o estilo base.

## Favicon

```ruby
def favicon_path
  icon = (current_theme && current_theme.favicon?) ? current_theme.favicon_path : 'favicon.ico'
  image_path(icon)
end
```

Basta existir um arquivo em `<tema>/favicon/` — o Redmine troca o favicon padrão
automaticamente em todas as páginas. Nenhuma configuração extra.

## Aplicando o tema

**Administração → Configurações → Exibição → Tema**, salvar.
O valor vai para `Setting.ui_theme` e é o `id` (nome do diretório).

## O que um tema NÃO pode fazer

O motor acima só cobre CSS, JS e assets. Portanto **um tema não altera**:
- As views ERB (não dá para mudar a estrutura HTML de verdade)
- Rotas, controllers, permissões
- Textos/traduções
- O menu (adicionar/remover itens de `top_menu`, `main_menu`, `account_menu`)

Tudo isso exige um **plugin**. Um tema pode *esconder* e *reposicionar* via CSS e
*reorganizar* via `theme.js` no DOM — ver [06](06-javascript-e-usabilidade.md)
para onde está a fronteira real.
