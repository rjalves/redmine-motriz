# 09 — O plugin fino: o que o tema não alcança

Fonte: `reference/redmine-lib-hook.rb` (`lib/redmine/hook.rb`) e
`reference/redmine7-layout-base.html.erb`.

> Este documento é sobre **a fronteira** tema × plugin. A API de plugins em si —
> ciclo de carga, DSL completa do `init.rb`, permissões, assets, migrations e testes —
> está em [14 — Desenvolvimento de plugins](14-plugins-tutorial.md).

Escopo decidido para este projeto: **tema para o visual + plugin fino para
estrutura.** Este documento delimita o que vai para cada lado.

## Divisão de responsabilidade

| Vai no **tema** | Vai no **plugin** |
|---|---|
| Paleta, tipografia, espaçamento, densidade | Itens novos de menu |
| Esconder/reposicionar via CSS | Colunas e filtros novos nas listagens |
| Layout por tela (`controller-*`/`action-*`) | Campos novos / macros de wiki |
| Branding por projeto (`project-*`) | Permissões, rotas, telas novas |
| Ícones (`images/icons.svg`) | Textos e traduções |
| Micro-ajustes de DOM no `theme.js` | Marcação nova dentro das views |

Regra prática: se precisa de **HTML que hoje não existe** ou de **dado que a view
não tem**, é plugin. O resto é tema.

## A API de hooks

```ruby
def call_hook(hook, context={})
  [].tap do |response|
    hls = hook_listeners(hook)
    if hls.any?
      hls.each {|listener| response << listener.send(hook, context)}
    end
  end
end
```

Um listener é uma classe que inclui `Singleton` (o `add_listener` levanta erro se
não incluir) e define um método com o nome do hook. Na prática herda-se de
`Redmine::Hook::ViewListener`, que já cuida disso.

O `context` recebido inclui, por padrão, `:project`, `:hook_caller` e — quando
disponível — `:controller` e `:request`. Cada view acrescenta o seu (a de tarefa
manda `:issue`, por exemplo).

Em views, o retorno de todos os listeners é concatenado com espaço e marcado como
`html_safe`.

## Hooks disponíveis no layout base

Presentes em **toda** página (ver `reference/redmine7-layout-base.html.erb`):

| Hook | Posição | Uso típico |
|---|---|---|
| `view_layouts_base_html_head` | dentro do `<head>` | injetar CSS/JS extra, meta tags |
| `view_layouts_base_body_top` | logo após `<body>` | faixa de aviso, banner global |
| `view_layouts_base_content` | fim de `#content` | bloco fixo em todas as telas |
| `view_layouts_base_body_bottom` | antes de `</body>` | scripts, widgets |
| `view_layouts_base_sidebar` | dentro de `#sidebar-wrapper` | via `view_layouts_base_sidebar_hook_response` |

Há muitos outros hooks espalhados nas views específicas (tarefas, projetos, wiki).
Para descobrir os disponíveis numa tela, procure no código-fonte da versão alvo:

```bash
grep -rn 'call_hook' app/views/ | grep -o 'call_hook :[a-z_]*' | sort -u
```

## Esqueleto do plugin

```
plugins/motriz_ui/
├─ init.rb
├─ lib/motriz_ui/hooks.rb
└─ assets/
   ├─ stylesheets/
   └─ javascripts/
```

`init.rb`:

```ruby
Redmine::Plugin.register :motriz_ui do
  name        'Motriz UI'
  author      'Roberto Alves'
  description 'Ajustes estruturais que acompanham o tema Motriz'
  version     '0.1.0'
  requires_redmine version_or_higher: '7.0.0'
end

# Referenciar a constante basta: o Zeitwerk carrega lib/motriz_ui/hooks.rb e o
# `inherited` de Listener registra o hook. NÃO use require/require_dependency —
# o Redmine 7 autoloada o lib/ do plugin e o require duplica a constante no reload.
MotrizUi::Hooks
```

`lib/motriz_ui/hooks.rb`:

```ruby
module MotrizUi
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context = {})
      # context[:project], context[:controller], context[:request]
      ''
    end
  end
end
```

Instalar: copiar para `plugins/`, rodar
`bundle exec rake redmine:plugins:migrate RAILS_ENV=production` (se houver
migrations) e **reiniciar**.

## Por que separar em vez de pôr tudo no plugin

O tema continua sendo trocável pelo dropdown de Administração — o usuário pode
desligar o visual sem perder a funcionalidade, e vice-versa. Também mantém o CSS
sujeito ao pipeline de temas (que resolve digest e fallback de ícone sozinho).

## Cuidados

- **Versionar junto.** Tema e plugin viram um par; um upgrade do Redmine pode
  quebrar hooks de view sem tocar no CSS.
- `requires_redmine` evita o plugin carregar numa versão incompatível.
- Hooks de view rodam em **toda** requisição correspondente — mantenha-os baratos,
  sem consulta ao banco sem necessidade.
- Assets de plugin ficam em `assets/` e são servidos sob `plugin_assets/<plugin>/`.
  O helper de ícones já reconhece esse caminho (`sprite_source` com `plugin:`).
  O subdiretório é **achatado** no caminho lógico, igual aos temas: nomes precisam
  ser únicos entre `images/`, `stylesheets/` e `javascripts/`.
