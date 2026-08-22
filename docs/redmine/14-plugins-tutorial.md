# 14 — Desenvolvimento de plugins (Redmine 7.0.0)

Base para criar plugins novos. Ponto de partida: o
[Plugin Tutorial oficial](https://www.redmine.org/projects/redmine/wiki/Plugin_Tutorial)
(lido em 21/08/2026), **conferido linha a linha contra o código-fonte em `redmine-7/`**.

> O tutorial da wiki está congelado na era Redmine 3.x/4.x. Vários trechos dele
> quebram ou são desnecessários no 7.0. A seção
> [Onde a wiki está errada para o 7.0](#onde-a-wiki-está-errada-para-o-70) lista
> as divergências; o resto deste documento já vem corrigido.

Fontes locais (`reference/`) — **grep nelas em vez de rebuscar na web**:
`redmine7-lib-plugin.rb`, `redmine7-lib-plugin_loader.rb`, `redmine7-lib-access_control.rb`,
`redmine7-lib-menu_manager.rb`, `redmine7-hook-listener.rb`, `redmine7-hook-view_listener.rb`,
`redmine7-hook-names.txt`, `redmine7-sample-plugin/`.

Este documento cobre plugins em geral. Para a fronteira **tema × plugin** neste
projeto, veja [09 — O plugin fino](09-plugin-fino.md).

---

## 1. O ciclo de carga

`lib/redmine/plugin_loader.rb` é quem manda. Entender essa ordem evita a maior
parte dos bugs de "meu código não roda".

```ruby
def self.load
  setup                 # varre plugins/*/ e monta um PluginPath por diretório
  add_autoload_paths    # empurra app/* e lib/ do plugin para o Zeitwerk

  Rails.application.config.to_prepare do
    PluginLoader.directories.each(&:run_initializer)   # load init.rb
    Redmine::Hook.call_hook :after_plugins_loaded
  end
end
```

Quatro consequências práticas:

1. **`init.rb` roda dentro de `to_prepare`.** Em desenvolvimento isso é a cada
   requisição/reload; em produção, uma vez no boot. Ele precisa ser idempotente —
   nada de acumular estado a cada chamada.
2. **`add_autoload_paths` roda antes**, e usa `Rails::Engine::Configuration` para
   descobrir os caminhos:
   ```ruby
   engine_cfg = Rails::Engine::Configuration.new(directory.to_s)
   engine_cfg.paths.add 'lib', eager_load: true
   engine_cfg.all_eager_load_paths.each do |dir|
     Rails.autoloaders.main.push_dir dir
     Rails.application.config.watchable_dirs[dir] = [:rb]
   end
   ```
   Ou seja: `app/models`, `app/controllers`, `app/helpers`, `app/mailers` **e `lib/`**
   entram no autoloader principal do Zeitwerk. `watchable_dirs` é o que faz o
   Redmine recarregar o plugin quando você edita um `.rb` em desenvolvimento.
3. **Não use `require` nem `require_dependency` no seu plugin.** O core do
   Redmine 7 não tem uma única ocorrência de `require_dependency`. Carregar
   manualmente um arquivo que o Zeitwerk também gerencia produz
   `Zeitwerk::NameError` ou constantes duplicadas depois de um reload.
4. **Nomeie pelo Zeitwerk.** Relativo à raiz de autoload, o caminho tem que casar
   com a constante: `lib/motriz_ui/hooks.rb` → `MotrizUi::Hooks`;
   `app/models/meeting.rb` → `Meeting`.

`config/routes.rb` do plugin é carregado por outro caminho — direto do
`config/routes.rb` do core, no fim do arquivo:

```ruby
Redmine::Plugin.directory.glob("*/config/routes.rb").sort.each do |plugin_routes_path|
  instance_eval(plugin_routes_path.read, plugin_routes_path.to_s)
```

Note o `.sort`: a ordem é **alfabética pelo nome do diretório**. Dois plugins que
declaram o mesmo `as:` colidem, e quem vem depois vence.

---

## 2. Criar o esqueleto

Geradores reais no 7.0 (`lib/generators/`):

```bash
# o plugin
bundle exec rails generate redmine_plugin motriz_ui

# um model + migration
bundle exec rails generate redmine_plugin_model motriz_ui meeting \
  project_id:integer:index description:string scheduled_on:datetime

# só uma migration
bundle exec rails generate redmine_plugin_migration motriz_ui add_color_to_meetings

# um controller + helper + views + teste funcional
bundle exec rails generate redmine_plugin_controller motriz_ui meetings index show
```

O `redmine_plugin_migration` **não existe no tutorial da wiki** — foi adicionado
depois (Patch #31498). Use-o para alterações de schema pós-criação.

Árvore gerada (`redmine_plugin_generator.rb`):

```
plugins/motriz_ui/
├─ init.rb
├─ README.rdoc
├─ app/{controllers,helpers,models,views}/
├─ assets/{images,javascripts,stylesheets}/
├─ config/
│  ├─ routes.rb
│  └─ locales/en.yml
├─ db/migrate/
├─ lib/tasks/
└─ test/{fixtures,unit,functional,integration,system}/
```

Diretórios que o gerador **não** cria mas o Redmine reconhece:

| Caminho | Para quê |
|---|---|
| `app/views/settings/_<algo>_settings.html.erb` | tela de configuração do plugin |
| `app/views/my/blocks/_<nome>.html.erb` | bloco novo na Minha Página (registro automático por glob) |
| `app/views/hooks/_<hook>.html.erb` | partials de hook, por convenção |
| `lib/<plugin>/` | módulos, listeners e patches (autoload Zeitwerk) |

> **O nome do diretório é o id do plugin.** `Plugin.register` levanta
> `PluginNotFound` se `plugins/<id>/` não existir — mesma regra que vale para temas.

---

## 3. `init.rb`: a DSL completa

O que `Redmine::Plugin` aceita, direto de `reference/redmine7-lib-plugin.rb`.

### Metadados

```ruby
Redmine::Plugin.register :motriz_ui do
  name        'Motriz UI'          # default: id.humanize
  description 'Ajustes estruturais que acompanham o tema Motriz'
  author      'Roberto Alves'
  author_url  'https://motrizdigital.com.br'
  url         'https://github.com/…'
  version     '0.1.0'
  directory   nil                  # default: plugins/<id>; raramente se mexe
end
```

`name`, `description`, `url`, `author`, `author_url` e `version` aparecem em
**Administração → Plugins**. `url` e `version` também alimentam o "Verificar
atualizações", que faz um JSONP para `redmine.org/plugins/check_updates`.

### Requisitos de versão

```ruby
requires_redmine version_or_higher: '7.0.0'
requires_redmine '7.0'                        # forma curta, mesma coisa
requires_redmine version: '7.0.0'             # exatamente essa
requires_redmine version: ['6.1.0', '7.0.0']  # uma dessas
requires_redmine version: '6.0'..'7.0'        # faixa inclusiva

requires_redmine_plugin :outro_plugin, version_or_higher: '1.2.0'
```

A comparação é por prefixo: `compare_versions` corta a versão atual no tamanho do
requisito, então `'7.0'` casa com qualquer 7.0.x. Falhar levanta
`PluginRequirementError` **no boot** — o Redmine não sobe. Para dependência
opcional, teste antes com `Redmine::Plugin.installed?(:outro_plugin)`.

### Permissões e módulos de projeto

```ruby
project_module :motriz_ui do
  permission :view_meetings,   { meetings: [:index, :show] }, require: :member, read: true
  permission :manage_meetings, { meetings: [:new, :create, :edit, :update, :destroy] }
  permission :say_hello,       { example: :say_hello }, public: true
end
```

Opções de `permission` (`Redmine::AccessControl::Permission`):

| Opção | Efeito |
|---|---|
| `public: true` | concedida implicitamente a qualquer um; **não aparece** na tela de papéis |
| `require: :loggedin` | só pode ser dada a usuários autenticados |
| `require: :member` | só pode ser dada a membros do projeto |
| `read: true` | continua valendo em **projetos fechados** (sem ela, a ação é bloqueada) |

Três armadilhas confirmadas em `Project#allows_to?` / `User#allowed_to?`:

- **`public: true` não fura o módulo.** Se a permissão está dentro de um
  `project_module` e o módulo está desligado no projeto, a ação é negada de
  qualquer forma.
- **Projeto arquivado nega tudo**, inclusive `read: true`.
- **Projeto fechado nega tudo que não seja `read: true`.** Se sua tela de leitura
  não abre num projeto fechado, é essa flag que falta.

Sem o bloco `project_module`, a permissão é global e sempre está disponível —
use para telas administrativas ou fora de projeto.

Do lado do controller, `authorize` é quem casa ação↔permissão:

```ruby
class MeetingsController < ApplicationController
  menu_item :motriz_meetings          # qual item do menu fica ativo
  before_action :find_project, :authorize

  private

  def find_project
    @project = Project.find(params[:project_id])
  end
end
```

`authorize` deriva a permissão de `params[:controller]/params[:action]`, e por
isso **toda ação precisa estar mapeada em algum `permission`** — ação não mapeada
resulta em 403.

### Menus

```ruby
menu :project_menu, :motriz_meetings,
     { controller: 'meetings', action: 'index' },
     caption:    :label_meeting_plural,   # Symbol → l(), String → literal, Proc → recebe o project
     after:      :activity,
     param:      :project_id,             # default :id
     permission: :view_meetings,
     icon:       'calendar',              # sprite SVG (Redmine 6+)
     plugin:     :motriz_ui,              # de onde vem o sprite: plugin_assets/motriz_ui/icons.svg
     html:       { class: 'motriz' },
     if:         ->(project) { project.module_enabled?(:motriz_ui) }

delete_menu_item :top_menu, :help
```

Menus existentes (`lib/redmine/preparation.rb`):
`:top_menu`, `:account_menu`, `:application_menu`, `:admin_menu`, `:project_menu`.
O docstring de `Plugin#menu` só cita quatro, mas `:admin_menu` é renderizado em
`app/views/admin/_menu.html.erb` e funciona.

Posicionamento: `first: true`, `last: true`, `before: :item`, `after: :item`,
`parent: :item` (submenu), `children: ->(project) { [...] }` (itens dinâmicos, tem
que ser um callable que devolve `MenuItem`s).

**`icon:` e `plugin:` são novidade do 6/7** e conectam direto no sprite SVG —
o mesmo mecanismo descrito em [05 — Ícones SVG](05-icones-svg.md).
`MenuItem` também acrescenta sozinho uma classe CSS com o nome do item
dasherizado, o que dá um gancho de estilo por item sem precisar de `html:`.

Duas validações que levantam `ArgumentError` no boot: `if:` e `children:`
precisam responder a `call`, `html:` precisa ser Hash.

### Configuração do plugin

```ruby
settings default: { 'sample_setting' => 'value' },
         partial: 'settings/motriz_ui_settings'
```

Cria a tela **Administração → Plugins → Configurar**, em
`/settings/plugin/motriz_ui`. O partial vive em
`app/views/settings/_motriz_ui_settings.html.erb`, e recebe `settings` como
variável local (o controller também expõe `@settings`):

```erb
<p>
  <label>Endereço padrão</label>
  <%= text_field_tag 'settings[notification_default]', settings['notification_default'] %>
</p>
```

Ler em qualquer lugar: `Setting.plugin_motriz_ui['notification_default']`.
Por baixo é `Setting.define_plugin_setting`, que define
`plugin_<id>` como um setting **serializado** — o valor é sempre um Hash de strings.

Dois detalhes que economizam depuração:

- O `SettingsController#plugin` faz `params[:settings].permit!.to_h` e **grava o
  hash inteiro**. Campo que não veio no POST some. Checkbox precisa de
  `hidden_field_tag` antes, senão desmarcar não persiste.
- O nome do partial é global entre plugins. Dois plugins com
  `partial: 'settings/settings'` disparam um `Rails.logger.warn` e **só um dos dois
  renderiza**. Prefixe com o id do plugin.

A tela envolve tudo em `<div id="settings" class="plugin plugin-motriz_ui">` —
gancho de CSS pronto.

### Outros registros

```ruby
activity_provider :meetings, class_name: 'Meeting', default: false
wiki_format_provider :custom_formatter, CustomFormatter, label: 'Meu formato'
attachment_object_type Meeting   # libera as rotas do core de anexos p/ o model
```

`activity_provider` exige que o model implemente `find_events` — na prática
`acts_as_activity_provider` + `acts_as_event`, como no `sample_plugin`. A permissão
`:view_<nome>` é necessária para os eventos aparecerem na Atividade.

`attachment_object_type` é obrigatório para `acts_as_attachable` funcionar em
model de plugin desde o CVE-2022-44030 (Feature #39948) — sem ele, o upload
retorna 404.

---

## 4. Hooks

`Redmine::Hook` (ver [09](09-plugin-fino.md) para a mecânica e
`reference/redmine7-hook-names.txt` para a lista completa: **62 hooks chamados de
`app/views/`**, 8 de helpers, 14 de controllers/models, mais `after_plugins_loaded`).

No Redmine 7 as classes foram separadas em arquivos próprios:
`lib/redmine/hook/listener.rb` e `lib/redmine/hook/view_listener.rb`.

```ruby
# lib/motriz_ui/hooks.rb  →  MotrizUi::Hooks
module MotrizUi
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_projects_show_left, partial: 'motriz_ui/project_overview'

    def view_layouts_base_html_head(context = {})
      stylesheet_link_tag('motriz_ui', plugin: 'motriz_ui')
    end
  end
end
```

`ViewListener` já inclui `Propshaft::Helper`, `ApplicationHelper`, os helpers de
tag/form/url e os `url_helpers` das rotas — dá para montar HTML sem view.
`Listener` inclui `Singleton` e se auto-registra em `inherited`.

`render_on` aceita **várias** `render_options` e renderiza todas em sequência:

```ruby
render_on :view_issues_show_details_bottom,
          { partial: 'a' },
          { partial: 'b' }
```

Ele delega para `context[:hook_caller].render` quando o chamador sabe renderizar,
senão para `context[:controller].render_to_string`; fora desses dois casos,
levanta. Por isso `render_on` num hook de model não funciona.

**Registrar o listener.** O tutorial manda `require_dependency` — errado no 7.
Basta referenciar a constante no `init.rb`, o que dispara o autoload do Zeitwerk:

```ruby
Redmine::Plugin.register :motriz_ui do
  # …
end

MotrizUi::Hooks   # força o autoload -> Listener.inherited -> Hook.add_listener
```

Como o `init.rb` já roda dentro de `to_prepare`, isso reexecuta a cada reload em
desenvolvimento, que é exatamente o que se quer.

Contexto que todo hook recebe: `:project`, `:hook_caller` e, quando existirem,
`:controller` e `:request`. Cada ponto de chamada acrescenta o seu.

---

## 5. Assets (Propshaft)

O Redmine 6/7 **não copia mais** assets de plugin para `public/plugin_assets/`.
Esse diretório continua no repositório, mas só com um arquivo `empty` dentro:
não há uma única chamada de cópia em `plugin.rb`, `plugin_loader.rb` ou nas rake
tasks. `plugin_assets/` virou apenas um **prefixo lógico** no Propshaft
(`config/initializers/30-redmine.rb`):

```ruby
Redmine::Plugin.all.each do |plugin|
  paths = plugin.asset_paths
  Rails.application.config.assets.redmine_extension_paths << paths if paths.present?
end
```

Os helpers do core aceitam `plugin:` e montam o caminho lógico:

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'motriz_ui', plugin: 'motriz_ui' %>
  <%= javascript_include_tag 'motriz_ui', plugin: 'motriz_ui' %>
<% end %>
<%= image_tag 'logo.svg', plugin: 'motriz_ui' %>
<%= sprite_icon('meeting', plugin: 'motriz_ui') %>
```

Em `sprite_icon`, o `plugin:` troca o **sprite inteiro** por
`plugin_assets/<id>/icons.svg` — o plugin precisa embarcar o próprio
`assets/images/icons.svg` com esse ícone dentro. Ver [05 — Ícones SVG](05-icones-svg.md).

### O subdiretório é achatado — mesma armadilha dos temas

`Plugin#asset_paths` usa `base_dir.children.select(&:directory?)` como raízes e
prefixa com `plugin_assets/<id>`. O nome da subpasta **não entra** no caminho
lógico:

```
plugins/motriz_ui/assets/stylesheets/motriz_ui.css  →  plugin_assets/motriz_ui/motriz_ui.css
plugins/motriz_ui/assets/images/logo.svg            →  plugin_assets/motriz_ui/logo.svg
plugins/motriz_ui/assets/javascripts/app.js         →  plugin_assets/motriz_ui/app.js
```

Ou seja: **nomes precisam ser únicos entre `images/`, `stylesheets/` e
`javascripts/`.** É a mesma correção #3 já registrada para temas no `CLAUDE.md`,
e vale igual para plugins.

Dentro de um CSS, referências relativas continuam funcionando
(`url(../images/it_works.png)` no `sample_plugin`) porque `Redmine::Asset` reescreve
os caminhos via `transition_map` — mas escrever `url(logo.svg)`, já achatado, é mais
previsível.

O `README` do `sample_plugin` ainda manda rodar `rake redmine:plugins` "para copiar
os assets". Hoje essa task só chama `redmine:plugins:migrate`; nada é copiado.

---

## 6. Migrations

```bash
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
bundle exec rake redmine:plugins:migrate NAME=motriz_ui
bundle exec rake redmine:plugins:migrate NAME=motriz_ui VERSION=0   # reverte tudo
```

`VERSION` **exige** `NAME` (a task aborta sem ele) e só aceita dígitos.
Ao final ela invoca `db:schema:dump`.

Como o Redmine isola as versões por plugin: `Plugin::Migrator` sobrescreve
`record_version_state_after_migrating` para gravar `"#{version}-#{plugin_id}"` na
tabela `schema_migrations`. Duas consequências:

- Nunca dá conflito de timestamp entre plugins.
- Não adianta procurar a versão do plugin com o `rake db:migrate:status` normal.

O gerador de model numera com `[maior_existente + 1, timestamp_utc].max`, então
migrations de plugin usam timestamp de 14 dígitos como as do core.

A classe base é versionada pelo Rails corrente:

```ruby
class CreateMeetings < ActiveRecord::Migration[8.1]
  def change
    create_table :meetings do |t|
      t.integer  :project_id, null: false
      t.string   :description
      t.datetime :scheduled_on
    end
    add_index :meetings, :project_id
  end
end
```

Models herdam de `ApplicationRecord` (é o default do gerador via `parent_class_name`),
não de `ActiveRecord::Base` como no tutorial.

---

## 7. Testes

`test_helper.rb` no 7.0 é uma linha, e **não** é a forma do tutorial:

```ruby
require_relative '../../../test/test_helper'
```

Preparar o banco de teste e rodar:

```bash
RAILS_ENV=test bundle exec rake db:drop db:create db:migrate \
  redmine:plugins:migrate redmine:load_default_data

bundle exec rake redmine:plugins:test NAME=motriz_ui
bundle exec rake redmine:plugins:test:units       NAME=motriz_ui
bundle exec rake redmine:plugins:test:functionals NAME=motriz_ui
bundle exec rake redmine:plugins:test:integration NAME=motriz_ui
bundle exec rake redmine:plugins:test:system      NAME=motriz_ui
```

Sem `NAME`, roda os testes de **todos** os plugins. As subtasks dependem de
`db:test:prepare`; a task `:test` guarda-chuva não.

Autorização em teste funcional — os três passos costumam ser necessários juntos:

```ruby
def test_index
  @request.session[:user_id] = 2
  Role.find(1).add_permission! :view_meetings
  Project.find(1).enabled_module_names = [:motriz_ui]

  get :index, params: { project_id: 1 }
  assert_response :success
end
```

Há ainda `rails test:autoload` com `REDMINE_PLUGINS_DIRECTORY` apontando para um
diretório de plugins — é como o core verifica que o Zeitwerk pega os arquivos do
plugin sem `require` (`test/autoload/plugin_autoload_test.rb`).

---

## 8. Alterar comportamento do core

Nada disso está no tutorial, e é onde plugin de verdade passa a maior parte do tempo.

**Sobrepor uma view do core.** `Plugin.register` faz
`ActionController::Base.prepend_view_path(<plugin>/app/views)`. Um arquivo em
`plugins/motriz_ui/app/views/issues/show.html.erb` **substitui** o do core. Poderoso
e frágil: qualquer upgrade do Redmine pode deixar sua cópia defasada em silêncio.
Prefira hook; use isto só quando não houver hook no ponto certo.

**Patch de classe.** Use `Module#prepend`, dentro do `init.rb` (que já está em
`to_prepare`), e nunca reabrindo a classe:

```ruby
# lib/motriz_ui/issue_patch.rb  →  MotrizUi::IssuePatch
module MotrizUi
  module IssuePatch
    def css_classes(user = User.current)
      "#{super} motriz-#{tracker.id}"
    end
  end
end

# init.rb, depois do register
Issue.prepend MotrizUi::IssuePatch
```

`prepend` é idempotente (Ruby ignora o segundo `prepend` do mesmo módulo), então
sobrevive aos reloads de desenvolvimento. O padrão antigo
`unloadable` + `alias_method_chain` está morto desde o Rails 5.

**`after_plugins_loaded`** é o gancho para quando você precisa que *todos* os
plugins já estejam registrados — por exemplo, para se integrar a outro plugin só
se ele estiver instalado.

**Outros registros do core** que um plugin pode estender. Os que o core popula em
`lib/redmine/preparation.rb` — `Redmine::Activity.map`, `Redmine::Search.map`,
`Redmine::WikiFormatting.map`, `Redmine::Scm::Base.add` — mais dois que vivem em
arquivo próprio:

```ruby
# macros de wiki — lib/redmine/wiki_formatting/macros.rb
Redmine::WikiFormatting::Macros.register do
  desc "Insere o painel da frente de trabalho."
  macro :motriz_painel do |obj, args|
    render partial: 'motriz_ui/painel', locals: { args: args }
  end
end

# formato novo de campo personalizado — lib/redmine/field_format.rb
Redmine::FieldFormat.add 'cnpj', CnpjFormat
```

**Bloco na Minha Página:** basta criar
`app/views/my/blocks/_meu_bloco.html.erb`. `Redmine::MyPage.additional_blocks`
descobre por glob em `plugins/*/app/views/my/blocks/_*.{rhtml,erb}` — não há
registro em `init.rb`. O rótulo sai de `my.blocks.<nome>` no locale.
O glob é memoizado em `@@additional_blocks`, então **criar o partial exige
reiniciar** — não basta o reload de desenvolvimento.

---

## 9. i18n

YAMLs em `config/locales/*.yml` entram no `i18n.load_path` no `register`.
Chaves seguem a convenção do core, e algumas são resolvidas automaticamente:

| Prefixo | Onde aparece |
|---|---|
| `permission_<nome>` | tela de Papéis e permissões |
| `project_module_<nome>` | aba Módulos nas configurações do projeto |
| `label_<item>` | legenda default de item de menu (`l_or_humanize`) |
| `field_<nome>` | rótulos de atributo |
| `my.blocks.<nome>` | nome do bloco na Minha Página |

```yaml
pt-BR:
  project_module_motriz_ui: Reuniões
  permission_view_meetings: Ver reuniões
  permission_manage_meetings: Gerenciar reuniões
  label_meeting_plural: Reuniões
```

Sem tradução, o Redmine cai no `humanize` do símbolo — funciona, mas em inglês.

---

## Onde a wiki está errada para o 7.0

| Wiki diz | No Redmine 7.0 |
|---|---|
| `require_dependency File.expand_path('../lib/polls_hook_listener', __FILE__)` no `init.rb` | Não existe mais no core. Quebra o Zeitwerk. Referencie a constante: `MotrizUi::Hooks` |
| `require File.expand_path('../../test_helper', __FILE__)` | O template gerado é `require_relative '../../../test/test_helper'` |
| `class Poll < ActiveRecord::Base` | O gerador cria com `ApplicationRecord` |
| `ActiveRecord::Migration[5.2]` | `ActiveRecord::Migration[8.1]` (Rails 8.1.3) — o template usa `ActiveRecord::Migration.current_version` |
| Assets do plugin são "copiados" para `public/plugin_assets` | Propshaft; `plugin_assets/<id>` é caminho lógico, nada é copiado. `rake redmine:plugins` só migra |
| `assets/stylesheets/voting.css` → referenciado como `'voting'` | Certo, mas a wiki não avisa que o subdiretório é **achatado** — nomes têm que ser únicos entre `images/`, `stylesheets/` e `javascripts/` |
| Menus aceitam `caption`, `after`, `param` | Também `permission`, `icon`, `plugin`, `if`, `html`, `parent`, `children`, `first`, `last`, `before` |
| `permission` aceita `:public` e `:require` | Também `:read` (necessário para a tela abrir em projeto fechado) |
| Não menciona | Gerador `redmine_plugin_migration` |
| Não menciona | `attachment_object_type` (obrigatório para `acts_as_attachable` em plugin) |
| Não menciona | `requires_redmine_plugin`, `Plugin.installed?` |
| Não menciona | Colisão de `settings[:partial]` entre plugins (só um renderiza) |
| Não menciona | `after_plugins_loaded`, `prepend_view_path`, blocos da Minha Página por glob |
| Migration de exemplo com `self.up`/`self.down` | O template gera `change` |
| Diretório de referência lista `test/{unit,functional,integration}` | O gerador também cria `test/system`, e há `redmine:plugins:test:system` |

Duas coisas da wiki que **continuam válidas** e vale reter: a tabela de menus e a
ideia de `delete_menu_item` para podar a navegação — útil justamente no plugin
fino deste projeto.
