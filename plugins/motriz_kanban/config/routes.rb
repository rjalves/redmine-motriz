# Rotas do plugin motriz_kanban.
#
# Este arquivo é lido por instance_eval de dentro do Rails.application.routes.draw
# do Redmine (redmine-7/config/routes.rb), por isso não leva o bloco `draw` em volta.
#
# Só GET: a tela lê. Quem grava é o BoardPositionsController do motriz_2, que já
# tem as próprias rotas PATCH/POST e a checagem de CSRF do Rails.
get 'quadro',                     :to => 'motriz_kanban#index', :as => 'motriz_kanban'
get 'projects/:project_id/quadro', :to => 'motriz_kanban#index', :as => 'project_motriz_kanban'
