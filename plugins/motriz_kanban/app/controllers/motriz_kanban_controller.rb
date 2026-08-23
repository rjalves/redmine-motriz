# frozen_string_literal: true

# Tela do quadro Kanban, global (/quadro) e por projeto (/projects/x/quadro).
#
# O trabalho aqui é só montar a consulta e entregar para a parcial do motriz_2.
# Todo o desenho, o arrastar-e-soltar e a persistência de posição são de lá.
class MotrizKanbanController < ApplicationController
  helper :queries
  include QueriesHelper
  helper :issues

  # A parcial do quadro usa render_query_totals e o formulário de filtros, que
  # levantam estas exceções quando um filtro guardado na sessão fica inválido —
  # por exemplo depois que alguém apaga o campo personalizado que ele filtrava.
  # Sem isto a tela dá 500 em vez de mostrar "filtro inválido".
  rescue_from Query::StatementInvalid, :with => :query_statement_invalid
  rescue_from Query::QueryError, :with => :query_error

  before_action :find_optional_project_and_authorize

  # Teto rígido de cartões.
  #
  # A parcial chama query.issues sem limite, e a lista de tarefas só escapa
  # disso porque pagina. Um quadro global com o filtro padrão "situação aberta"
  # carregaria todas as tarefas abertas de todos os projetos visíveis e montaria
  # um cartão para cada uma no DOM. Acima deste teto a tela avisa que está
  # truncada e pede um filtro mais estreito.
  LIMITE_DE_CARTOES = 500

  def index
    retrieve_query(IssueQuery, true)

    if @query.valid?
      @issue_count = @query.issue_count
      # O override Deface query_form_board_options lê Array(@issues) para saber
      # quais situações marcar; sem esta atribuição as caixas vêm desmarcadas.
      @issues = @query.issues(:limit => LIMITE_DE_CARTOES)
      @truncado = @issue_count > LIMITE_DE_CARTOES
    end
  end

  private

  # Não dá para usar o find_optional_project do core aqui: ele termina em
  # authorize_global, que resolve a permissão pelo par controller/action —
  # "motriz_kanban/index" não está registrado em permissão nenhuma, então
  # devolveria 403 para todo mundo, inclusive administrador dentro de projeto.
  # A autorização certa é a mesma da lista de tarefas.
  def find_optional_project_and_authorize
    @project = Project.find(params[:project_id]) if params[:project_id].present?

    unless User.current.allowed_to?(:view_issues, @project, :global => @project.nil?)
      deny_access
      return false
    end

    true
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
