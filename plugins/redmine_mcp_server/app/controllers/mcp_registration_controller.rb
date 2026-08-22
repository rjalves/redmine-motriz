# frozen_string_literal: true

# Registro dinâmico de cliente (RFC 7591).
#
# O Redmine não tem isso, e sem ele o conector do Claude não consegue obter um
# client_id sozinho — o admin teria que pré-criar a aplicação e cada pessoa
# colar o id na configuração avançada do conector. Esse plano B continua válido
# e está no README; este endpoint só remove o atrito.
#
# É um endpoint anônimo que cria linhas em oauth_applications, então vem
# desligado por padrão e com três amarras: setting de habilitação, limite por IP
# e validação estrita de redirect_uri. As aplicações criadas são públicas
# (confidential: false), o que é o correto para cliente nativo com PKCE e
# significa que não há segredo emitido para vazar.
class McpRegistrationController < ApplicationController
  skip_before_action :check_if_login_required
  skip_before_action :check_password_change
  skip_before_action :check_twofa_activation
  skip_before_action :verify_authenticity_token

  before_action :require_registration_enabled
  before_action :throttle_by_ip

  NAME_PREFIX = 'MCP: '
  MAX_REDIRECT_URIS = 5

  def create
    params_hash = parse_body
    redirect_uris = Array(params_hash['redirect_uris']).compact_blank
    return error('invalid_redirect_uri', 'redirect_uris is required') if redirect_uris.empty?
    if redirect_uris.size > MAX_REDIRECT_URIS
      return error('invalid_redirect_uri', "At most #{MAX_REDIRECT_URIS} redirect_uris")
    end

    invalid = redirect_uris.reject { |u| acceptable_redirect_uri?(u) }
    if invalid.any?
      return error('invalid_redirect_uri',
                   "Redirect URIs must be https, or http on localhost: #{invalid.join(', ')}")
    end

    app = Doorkeeper::Application.new(
      name: application_name(params_hash),
      redirect_uri: redirect_uris.join("\n"),
      scopes: RedmineMcpServer::Config::SCOPES.join(' '),
      confidential: false
    )

    unless app.save
      return error('invalid_client_metadata', app.errors.full_messages.join('; '))
    end

    Rails.logger.info("MCP: registered OAuth client '#{app.name}' (uid #{app.uid}) from #{request.remote_ip}")

    render json: {
      'client_id' => app.uid,
      'client_id_issued_at' => Time.now.to_i,
      'redirect_uris' => redirect_uris,
      'token_endpoint_auth_method' => 'none',
      'grant_types' => %w[authorization_code refresh_token],
      'response_types' => ['code'],
      'client_name' => app.name,
      'scope' => app.scopes.to_s
    }, status: :created
  end

  private

  def application_name(params_hash)
    given = params_hash['client_name'].to_s.strip.presence || 'unnamed client'
    # Prefixo para o admin distinguir na tela de aplicações OAuth o que veio do
    # registro automático — a tabela oauth_applications não tem dono.
    "#{NAME_PREFIX}#{given}".truncate(255)
  end

  # A especificação exige HTTPS ou localhost. O Doorkeeper já aplica
  # force_ssl_in_redirect_uri (30-redmine.rb:61), mas validar aqui devolve um
  # erro no formato da RFC 7591 em vez de um erro de validação do model.
  def acceptable_redirect_uri?(value)
    uri = URI.parse(value.to_s)
    return false if uri.fragment.present?
    return true if uri.scheme == 'https'
    return true if uri.scheme == 'http' && %w[localhost 127.0.0.1 ::1].include?(uri.host)

    false
  rescue URI::InvalidURIError
    false
  end

  def require_registration_enabled
    return if RedmineMcpServer::Config.available? &&
              RedmineMcpServer::Config.dynamic_registration_enabled?

    error('access_denied', 'Dynamic client registration is disabled on this server', :forbidden)
  end

  def throttle_by_ip
    key = "mcp_server/register/#{request.remote_ip}/#{Time.now.utc.strftime('%Y%m%d%H')}"
    count = Rails.cache.increment(key, 1, expires_in: 1.hour)
    if count.nil?
      Rails.cache.write(key, 1, expires_in: 1.hour, raw: true)
      count = 1
    end
    return if count <= 10

    error('temporarily_unavailable', 'Too many registrations from this address', :too_many_requests)
  end

  def parse_body
    JSON.parse(request.raw_post.to_s.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def error(code, description, status = :bad_request)
    render json: {'error' => code, 'error_description' => description}, status: status
  end
end
