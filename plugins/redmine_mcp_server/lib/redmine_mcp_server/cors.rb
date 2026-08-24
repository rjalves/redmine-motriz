# frozen_string_literal: true

module RedmineMcpServer
  # CORS para clientes MCP que rodam no navegador.
  #
  # O conector do Claude não fala com o servidor só de servidor para servidor:
  # ele também sonda o endpoint a partir da página. Sem responder ao preflight
  # e sem os cabeçalhos, o navegador nem emite o POST, e o cliente reporta um
  # genérico "credential validation failed".
  #
  # Isto NÃO enfraquece a proteção contra DNS rebinding que a especificação
  # exige: origem desconhecida continua recebendo 403. O que muda é que agora
  # existe uma lista de origens legítimas, configurável.
  module Cors
    extend ActiveSupport::Concern

    # Cabeçalhos que o cliente precisa LER na resposta. WWW-Authenticate é o
    # mais importante: é por ele que um cliente de navegador descobre, no 401,
    # onde fica o documento de metadados do recurso. Sem expor, o fluxo de
    # descoberta trava sem erro visível.
    EXPOSE = 'WWW-Authenticate'

    # Cabeçalhos sempre aceitos. Os Mcp-Param-* são abertos por definição
    # (a especificação deixa o servidor nomear), então o preflight ecoa o que
    # o navegador pediu em vez de manter uma lista que envelhece.
    BASE_REQUEST_HEADERS = %w[
      Authorization Content-Type Accept
      MCP-Protocol-Version Mcp-Method Mcp-Name Last-Event-ID
    ].freeze

    def cors_origin_allowed?(origin)
      return false if origin.blank?

      allowed = RedmineMcpServer::Config.allowed_origins
      allowed << "#{request.protocol}#{request.host_with_port}"
      allowed << RedmineMcpServer::Config.base_url if RedmineMcpServer::Config.base_url.present?
      allowed.compact_blank.include?(origin)
    end

    def apply_cors_headers!(origin, methods)
      response.headers['Access-Control-Allow-Origin'] = origin
      response.headers['Access-Control-Allow-Methods'] = methods
      response.headers['Access-Control-Expose-Headers'] = EXPOSE
      # Origem entra na resposta, então proxies precisam variar por ela.
      response.headers['Vary'] = [response.headers['Vary'], 'Origin'].compact_blank.join(', ')
    end

    def apply_preflight_headers!(origin, methods)
      apply_cors_headers!(origin, methods)
      pedidos = request.headers['Access-Control-Request-Headers'].to_s.split(',').map(&:strip)
      response.headers['Access-Control-Allow-Headers'] =
        (BASE_REQUEST_HEADERS + pedidos).uniq { |h| h.downcase }.join(', ')
      response.headers['Access-Control-Max-Age'] = '86400'
    end
  end
end
