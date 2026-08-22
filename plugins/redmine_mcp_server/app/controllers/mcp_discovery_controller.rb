# frozen_string_literal: true

# Os documentos de descoberta que o Redmine não publica.
#
# O Doorkeeper do Redmine é um authorization server completo (authorization_code
# + PKCE + refresh token), mas não anuncia nada: um `grep` por `well-known` na
# árvore do core não retorna uma linha. Sem esses dois documentos, um cliente
# MCP não tem como descobrir onde autenticar, e a especificação exige ambos.
#
# Público por definição — são metadados de descoberta, sem dado de ninguém.
class McpDiscoveryController < ApplicationController
  skip_before_action :check_if_login_required
  skip_before_action :check_password_change
  skip_before_action :check_twofa_activation
  skip_before_action :verify_authenticity_token

  # RFC 9728. O cliente chega aqui pelo header WWW-Authenticate do 401.
  def protected_resource
    render json: {
      'resource' => RedmineMcpServer::Config.resource_uri,
      'authorization_servers' => [base],
      'scopes_supported' => RedmineMcpServer::Config::SCOPES,
      'bearer_methods_supported' => ['header'],
      'resource_name' => Setting.app_title,
      'resource_documentation' => "#{base}/mcp/help"
    }
  end

  # RFC 8414, descrevendo o Doorkeeper que já existe. Os caminhos vêm de
  # `use_doorkeeper` em config/routes.rb:21-23, sem customização.
  def authorization_server
    render json: {
      'issuer' => base,
      'authorization_endpoint' => "#{base}/oauth/authorize",
      'token_endpoint' => "#{base}/oauth/token",
      'revocation_endpoint' => "#{base}/oauth/revoke",
      'registration_endpoint' => registration_endpoint,
      'scopes_supported' => RedmineMcpServer::Config::SCOPES,
      'response_types_supported' => ['code'],
      'grant_types_supported' => %w[authorization_code refresh_token],
      'token_endpoint_auth_methods_supported' => %w[client_secret_basic client_secret_post none],
      # S256 apenas: "plain" existe no PKCE mas não protege contra intercepção.
      'code_challenge_methods_supported' => ['S256'],
      'service_documentation' => 'https://www.redmine.org/projects/redmine/wiki/Rest_api'
    }.compact
  end

  private

  def base
    RedmineMcpServer::Config.base_url
  end

  def registration_endpoint
    return nil unless RedmineMcpServer::Config.dynamic_registration_enabled?

    "#{base}/mcp/register"
  end
end
