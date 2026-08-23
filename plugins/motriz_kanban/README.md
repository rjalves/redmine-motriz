# motriz_kanban

Aba **Quadro** com a visão Kanban das tarefas — global e dentro de cada projeto.

## O que este plugin é, e o que ele não é

Ele **não tem quadro próprio**. O quadro é do `motriz_2`:

| Peça | Onde mora |
|---|---|
| Colunas, raias, cartões | `motriz_2/app/views/issues/_board.html.erb` e `_board_card.html.erb` |
| Arrastar e soltar | `motriz_2/assets/javascripts/controllers/board_controller.js` |
| Gravar a mudança de situação | `motriz_2/app/controllers/board_positions_controller.rb` |
| Ordem dos cartões | `motriz_2/app/models/board_card_position.rb` + migração |
| Estilo (`.board-*`) | `motriz_2/assets/src/issue.css`, compilado em `application.css` |
| Opções de coluna na consulta | `motriz_2/lib/redmine_asap_theme/issue_query_patch.rb` |

O que **este** plugin acrescenta são 4 arquivos: um controller que monta a
consulta, uma view que chama a parcial do `motriz_2`, duas rotas e um rótulo.

Antes dele, a única porta de entrada para o quadro era o alternador
Tabela/Quadro dentro da lista de tarefas, atrás de uma preferência por usuário.

## Dependência

`motriz_2` ≥ 2.4.0 é **obrigatório**, e o `init.rb` declara isso com
`requires_redmine_plugin`. Sem ele o boot falha com mensagem clara, em vez de um
`NameError` obscuro na primeira visita.

## Decisões que não são óbvias

- **Menu global vai em `:application_menu`, não em `:top_menu`.** O layout do
  `motriz_2` substitui o `base.html.erb` do core e nunca chama
  `render_menu :top_menu` — um item lá seria invisível. O que ele renderiza é
  `render_main_menu`, que sem projeto resolve para `:application_menu`.
- **A aba de projeto precisa de `:permission => :view_issues` explícita.** Sem
  ela o `MenuItem#allowed?` infere a permissão pelo par controller/action, e
  `motriz_kanban/index` não está registrado em permissão nenhuma — a aba sumiria
  até para o administrador, porque `Project#allows_to?` é consultado antes do
  `return true if admin?`.
- **O controller não usa `find_optional_project` do core**, pelo mesmo motivo:
  ele termina em `authorize_global`, que resolveria a permissão pelo
  controller/action e devolveria 403 para todo mundo. A autorização é feita à mão
  contra `:view_issues`.
- **Nenhuma permissão nova é criada.** O quadro é outra forma de olhar as mesmas
  tarefas: herda a visibilidade da lista e fica amarrado ao módulo
  `issue_tracking`. Uma permissão nova nasceria desmarcada em todos os papéis.
- **Teto de 500 cartões** (`LIMITE_DE_CARTOES`). A parcial não paginava; um
  quadro global sem filtro carregaria todas as tarefas abertas visíveis. Acima do
  teto a tela avisa que está truncada.

## Limitações conhecidas

- **Na visão global, reordenar cartões dentro de uma coluna não persiste.** A
  tabela `board_card_positions` é indexada por projeto; sem projeto no contexto
  o `board_controller.js` nem tenta gravar. Arrastar **entre** colunas funciona
  normalmente, porque isso muda a situação da tarefa. Dentro de um projeto, a
  ordem persiste.
- Salvar uma consulta a partir do quadro leva de volta para a lista de tarefas —
  é o `QueriesController#create` do core que redireciona.
