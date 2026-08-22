# frozen_string_literal: true

# Tela de auditoria das chamadas de ferramenta, para o administrador.
class McpToolCallsController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin

  def index
    scope = McpToolCall.includes(:user).recent
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    scope = scope.where(tool_name: params[:tool_name]) if params[:tool_name].present?
    scope = scope.failed if params[:only_failed] == '1'
    scope = scope.writes if params[:only_writes] == '1'

    @limit = per_page_option
    @count = scope.count
    @pages = Redmine::Pagination::Paginator.new(@count, @limit, params[:page])
    @calls = scope.limit(@limit).offset(@pages.offset).to_a

    @tool_names = McpToolCall.distinct.pluck(:tool_name).compact.sort
  end
end
