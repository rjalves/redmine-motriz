# frozen_string_literal: true

# Habilitação do MCP pela própria pessoa, em Minha conta.
#
# A preferência mora em UserPreference#others (`user.pref[:mcp_enabled]`) — o
# mesmo mecanismo que o tema motriz_2 já usa para `issue_panel_beta`. Não vale
# uma tabela só para um booleano.
class McpAccessController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :require_mcp_enabled_globally

  def update
    # Nunca por GET: é mudança de estado.
    enabled = params[:enabled].to_s == '1'
    User.current.pref[:mcp_enabled] = enabled ? '1' : '0'
    User.current.pref.save

    Rails.logger.info("MCP: access #{enabled ? 'enabled' : 'disabled'} by '#{User.current.login}'")
    flash[:notice] = l(enabled ? :notice_mcp_enabled : :notice_mcp_disabled)
    redirect_to my_account_path
  end

  # Revoga todos os tokens OAuth do usuário. É a saída de emergência quando
  # alguém desconfia que um assistente ficou com acesso indevido.
  def revoke_tokens
    tokens = Doorkeeper::AccessToken.where(resource_owner_id: User.current.id, revoked_at: nil)
    count = tokens.count
    tokens.find_each { |t| t.revoke }
    Rails.logger.warn("MCP: '#{User.current.login}' revoked #{count} OAuth token(s)")
    flash[:notice] = l(:notice_mcp_tokens_revoked, count: count)
    redirect_to my_account_path
  end

  private

  def require_mcp_enabled_globally
    render_404 unless RedmineMcpServer::Config.enabled?
  end
end
