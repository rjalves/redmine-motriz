# frozen_string_literal: true

# O endpoint MCP: POST /mcp.
#
# Herda de ApplicationController para reaproveitar find_current_user, que já
# resolve o Bearer token do Doorkeeper e — o que mais importa — aplica
# `user.oauth_scope = access_token.scopes` (application_controller.rb:134-141).
# É esse ivar que faz Role#allowed_to? intersectar o escopo do token com as
# permissões do papel. Todo o modelo de permissão vem daí; nenhuma linha aqui
# decide quem pode o quê.
#
# Três amarrações não óbvias, sem as quais isto não funciona:
#
#   1. A rota fixa `defaults: {format: 'json'}`. `api_request?` é
#      `%w(xml json).include? params[:format]` e é só isso que faz o CSRF ser
#      pulado (application_controller.rb:43-47). Sem o format, todo POST morre
#      em 422.
#   2. `accept_api_auth :handle` — o ramo OAuth de find_current_user (:130) só
#      roda se a ação estiver declarada. Sem isso o Bearer é ignorado EM
#      SILÊNCIO e a requisição vira anônima.
#   3. `Setting.rest_api_enabled?` precisa estar ligado, senão o mesmo :130
#      nunca chega ao Doorkeeper.
class McpController < ApplicationController
  include RedmineMcpServer::Cors

  accept_api_auth :handle

  # Autenticação aqui é Bearer com desafio RFC 9728, não redirecionamento para
  # a tela de login.
  skip_before_action :check_if_login_required
  skip_before_action :check_password_change
  skip_before_action :check_twofa_activation

  # Corpo com JSON quebrado estoura dentro do parser de params do Rails, que
  # roda em verify_authenticity_token — antes de qualquer linha desta classe.
  # Sem isto o cliente recebe o 400 genérico do Rails em vez de um erro
  # JSON-RPC, e não tem como distinguir "meu JSON está torto" de outras falhas.
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_rpc_error(RedmineMcpServer::Envelope::PARSE_ERROR,
                     'Invalid JSON in request body', status: :bad_request)
  end

  before_action :log_protocol_headers, except: :preflight
  before_action :reject_non_post, except: :preflight
  before_action :validate_origin
  before_action :require_mcp_available, except: :preflight
  before_action :require_mcp_user, except: :preflight

  # Resposta ao preflight. Só chega aqui se validate_origin aprovou a origem.
  def preflight
    apply_preflight_headers!(request.headers['Origin'], 'POST, OPTIONS')
    head :no_content
  end

  def handle
    body = parse_body
    envelope = RedmineMcpServer::Envelope.parse(request, body)

    result = RedmineMcpServer::Dispatcher.new(User.current, envelope).call

    # Notificação não recebe resposta (JSON-RPC 2.0).
    return head(:accepted) if envelope.notification?

    render json: {'jsonrpc' => '2.0', 'id' => envelope.id, 'result' => result}
  rescue RedmineMcpServer::Envelope::Error => e
    render_rpc_error(e.code, e.message, status: e.http_status, id: body_id(body), data: e.data)
  end

  private

  # O log do Rails registra o corpo (via Parameters) mas não os cabeçalhos, e é
  # nos cabeçalhos que mora metade do contrato desta revisão. Sem esta linha,
  # diagnosticar um -32020 vira adivinhação sobre o que o cliente mandou.
  # `Authorization` fica de fora de propósito: não se escreve token em log.
  def log_protocol_headers
    interesting = {
      'proto' => request.headers['MCP-Protocol-Version'],
      'method' => request.headers['Mcp-Method'],
      'name' => request.headers['Mcp-Name'],
      'origin' => request.headers['Origin'],
      'auth' => request.headers['Authorization'].present? ? 'bearer' : 'none'
    }.compact_blank.map { |k, v| "#{k}=#{v}" }.join(' ')
    Rails.logger.info("MCP headers: #{interesting}")
  end

  # A revisão 2026-07-28 removeu o stream por GET e o encerramento por DELETE.
  def reject_non_post
    return if request.post?

    response.headers['Allow'] = 'POST'
    render_rpc_error(RedmineMcpServer::Envelope::INVALID_REQUEST,
                     'Only POST is supported on the MCP endpoint',
                     status: :method_not_allowed)
  end

  # Exigência da especificação, contra DNS rebinding: Origin presente e
  # desconhecida é 403. Origin ausente (cliente não-navegador, como o backend
  # do Claude) passa direto — não há navegador para enganar.
  #
  # Quando a origem É conhecida, a resposta precisa carregar os cabeçalhos CORS,
  # senão o navegador descarta um 200 perfeitamente válido.
  def validate_origin
    origin = request.headers['Origin'].presence
    return if origin.nil?

    if cors_origin_allowed?(origin)
      apply_cors_headers!(origin, 'POST, OPTIONS')
      return
    end

    render_rpc_error(RedmineMcpServer::Envelope::INVALID_REQUEST,
                     'Origin not allowed', status: :forbidden)
  end

  def require_mcp_available
    return if RedmineMcpServer::Config.available?

    reason = if !RedmineMcpServer::Config.enabled?
               'The MCP server is disabled on this Redmine instance.'
             else
               'The Redmine REST API is disabled; the MCP server cannot authenticate.'
             end
    render_rpc_error(RedmineMcpServer::Envelope::INVALID_REQUEST, reason, status: :service_unavailable)
  end

  def require_mcp_user
    # User.current.logged? cobre de uma vez o token ausente, o inválido e o caso
    # do dono bloqueado — em que o core deixaria User.current anônimo.
    unless User.current.logged?
      return unauthorized('Authentication required')
    end
    return if RedmineMcpServer::Config.enabled_for?(User.current)

    render_rpc_error(RedmineMcpServer::Envelope::INVALID_REQUEST,
                     'You have not enabled MCP access. Turn it on in My account.',
                     status: :forbidden)
  end

  # 401 no formato da RFC 9728: aponta o documento de metadados do recurso, para
  # o cliente descobrir sozinho onde autenticar.
  def unauthorized(message)
    response.headers['WWW-Authenticate'] =
      %(Bearer realm="Redmine MCP", ) +
      %(resource_metadata="#{RedmineMcpServer::Config.base_url}/.well-known/oauth-protected-resource", ) +
      %(scope="#{RedmineMcpServer::Config::SCOPES.join(' ')}")
    render_rpc_error(RedmineMcpServer::Envelope::INVALID_REQUEST, message, status: :unauthorized)
  end

  def parse_body
    raw = request.raw_post.to_s
    raise RedmineMcpServer::Envelope::Error.new(
      RedmineMcpServer::Envelope::PARSE_ERROR, 'Empty request body'
    ) if raw.strip.empty?

    JSON.parse(raw)
  rescue JSON::ParserError => e
    raise RedmineMcpServer::Envelope::Error.new(
      RedmineMcpServer::Envelope::PARSE_ERROR, "Invalid JSON: #{e.message}"
    )
  end

  def body_id(body)
    body.is_a?(Hash) ? body['id'] : nil
  end

  def render_rpc_error(code, message, status:, id: nil, data: nil)
    error = {'code' => code, 'message' => message}
    error['data'] = data if data
    render json: {'jsonrpc' => '2.0', 'id' => id, 'error' => error}, status: status
  end
end
