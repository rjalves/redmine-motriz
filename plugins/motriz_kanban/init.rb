require 'redmine'

# Acesso direto ao quadro Kanban.
#
# O quadro em si não mora aqui: ele é do motriz_2, em app/views/issues/_board*,
# mais o controller Stimulus `board`, o BoardPositionsController e o CSS
# `board-*`. Até agora só dava para chegar nele pelo alternador Tabela/Quadro
# dentro da lista de tarefas, escondido atrás de uma preferência por usuário.
# Este plugin acrescenta o caminho que faltava — uma aba própria, global e por
# projeto — sem duplicar uma linha do quadro.
#
# Por que um plugin separado em vez de mais uma edição no motriz_2: o motriz_2 é
# um fork do Redmine ASAP Theme e ainda pode receber atualizações do upstream.
# Quanto menos coisa nossa morar lá dentro, mais barato é resincronizar.
Redmine::Plugin.register :motriz_kanban do
  name 'Motriz Quadro'
  author 'Motriz Digital'
  description 'Aba "Quadro" com a visão Kanban das tarefas, global e por projeto'
  version '1.0.0'
  requires_redmine version_or_higher: '7.0.0'

  # Dependência rígida, declarada de propósito: sem o motriz_2 não existem as
  # parciais do quadro, o modelo BoardCardPosition, o `avatar_with_local`, as
  # colunas de cor dos trackers nem o CSS. Melhor falhar no boot com esta
  # mensagem do que com um NameError obscuro na primeira visita à tela.
  requires_redmine_plugin :motriz_2, version_or_higher: '2.4.0'

  # --- barra de abas fora de projeto -------------------------------------
  #
  # :application_menu e NÃO :top_menu. O layout do motriz_2
  # (app/views/layouts/base.html.erb) só renderiza :tools_menu, :admin_menu e
  # render_main_menu — um item de :top_menu simplesmente não apareceria. É a
  # mesma razão pela qual o próprio motriz_2 registra "Minha página" no
  # :tools_menu. O render_main_menu, sem projeto, resolve para :application_menu.
  #
  # O :if é obrigatório: MenuItem#allowed? (lib/redmine/menu_manager.rb) só
  # entra no ramo de permissão quando há user E project. Fora de projeto não há
  # projeto, então sem esta guarda o item apareceria inclusive para anônimo.
  menu :application_menu, :motriz_kanban,
       {:controller => 'motriz_kanban', :action => 'index'},
       :caption => :label_motriz_quadro,
       :after => :issues,
       :if => proc { User.current.allowed_to?(:view_issues, nil, :global => true) }

  # --- aba dentro do projeto ---------------------------------------------
  #
  # :param => :project_id porque a rota é /projects/:project_id/quadro; sem isso
  # o Redmine passaria o projeto como :id e a rota não casaria.
  #
  # :permission explícita é indispensável. Sem ela o allowed? cai no ramo que
  # infere a permissão do par controller/action, e "motriz_kanban/index" não
  # está registrado em permissão nenhuma. Project#allows_to? devolveria false e
  # a aba ficaria escondida inclusive para o administrador, porque essa checagem
  # vem antes do `return true if admin?` em User#allowed_to?.
  #
  # Reaproveitar :view_issues em vez de criar permissão nova é deliberado: o
  # quadro é outra forma de olhar as mesmas tarefas, então herda exatamente a
  # visibilidade da lista e fica amarrado ao módulo issue_tracking. Uma
  # permissão nova nasceria desmarcada em todos os papéis e ninguém veria nada
  # até um administrador marcar uma a uma.
  menu :project_menu, :motriz_kanban,
       {:controller => 'motriz_kanban', :action => 'index'},
       :param => :project_id,
       :caption => :label_motriz_quadro,
       :after => :issues,
       :permission => :view_issues
end
