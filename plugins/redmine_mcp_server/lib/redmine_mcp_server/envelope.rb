# frozen_string_literal: true

module RedmineMcpServer
  # Valida o envelope de uma requisição MCP: o corpo JSON-RPC e os cabeçalhos
  # HTTP que a revisão 2026-07-28 espelha a partir dele.
  #
  # O espelhamento existe para que balanceadores e gateways roteiem sem abrir o
  # corpo. Daí a exigência de que header e corpo casem: se dois componentes da
  # rede olham fontes diferentes, um pode rotear por um valor e o servidor
  # executar outro.
  class Envelope
    # Códigos definidos pela especificação (basic/index, "Error Codes").
    # A faixa -32020..-32099 é reservada; não inventar código nela.
    HEADER_MISMATCH               = -32020
    MISSING_CLIENT_CAPABILITY     = -32021
    UNSUPPORTED_PROTOCOL_VERSION  = -32022
    INVALID_PARAMS                = -32602
    METHOD_NOT_FOUND              = -32601
    PARSE_ERROR                   = -32700
    INVALID_REQUEST               = -32600

    META_VERSION      = 'io.modelcontextprotocol/protocolVersion'
    META_CAPABILITIES = 'io.modelcontextprotocol/clientCapabilities'
    META_CLIENT_INFO  = 'io.modelcontextprotocol/clientInfo'

    # Os cabeçalhos espelhados só passaram a ser exigidos em 2026-07-28.
    MIRRORED_HEADERS_SINCE = '2026-07-28'

    # Métodos cujo params.name (ou params.uri) vai no cabeçalho Mcp-Name.
    NAMED_METHODS = {
      'tools/call'     => 'name',
      'prompts/get'    => 'name',
      'resources/read' => 'uri'
    }.freeze

    BASE64_SENTINEL = /\A=\?base64\?(.*)\?=\z/

    # Erro que já sabe virar resposta HTTP + JSON-RPC.
    class Error < StandardError
      attr_reader :code, :http_status, :data

      def initialize(code, message, http_status: 400, data: nil)
        @code = code
        @http_status = http_status
        @data = data
        super(message)
      end
    end

    attr_reader :method_name, :id, :params, :protocol_version, :client_info

    def self.parse(request, body)
      new(request, body).tap(&:validate!)
    end

    # Decodifica o sentinela =?base64?…?= usado quando o valor não cabe em ASCII
    # visível. Vale para Mcp-Name e Mcp-Param-*.
    def self.decode_header(value)
      return nil if value.nil?

      if (m = BASE64_SENTINEL.match(value))
        begin
          Base64.strict_decode64(m[1]).force_encoding(Encoding::UTF_8)
        rescue ArgumentError
          value
        end
      else
        value
      end
    end

    def initialize(request, body)
      @request = request
      @body = body.is_a?(Hash) ? body : {}
      @method_name = @body['method'].to_s
      @id = @body['id']
      @params = @body['params'].is_a?(Hash) ? @body['params'] : {}
      @meta = @params['_meta'].is_a?(Hash) ? @params['_meta'] : {}
      @protocol_version = resolve_protocol_version
      @client_info = @meta[META_CLIENT_INFO]
    end

    # Notificação é requisição sem id (JSON-RPC 2.0).
    def notification?
      !@body.key?('id') || @id.nil?
    end

    def modern?
      @protocol_version == MIRRORED_HEADERS_SINCE
    end

    def validate!
      validate_jsonrpc!
      validate_protocol_version!
      validate_meta!
      validate_mirrored_headers!
      true
    end

    private

    def header(name)
      @request.headers[name].presence
    end

    # O cabeçalho manda; na ausência dele cai para o _meta; na ausência dos dois,
    # a especificação permite assumir 2025-03-26 (era anterior ao cabeçalho).
    def resolve_protocol_version
      header('MCP-Protocol-Version') || @meta[META_VERSION].presence || '2025-03-26'
    end

    def validate_jsonrpc!
      if @body['jsonrpc'].to_s != '2.0'
        raise Error.new(INVALID_REQUEST, 'jsonrpc must be "2.0"')
      end
      return if @method_name.present?

      raise Error.new(INVALID_REQUEST, 'method is required')
    end

    def validate_protocol_version!
      return if Config::SUPPORTED_PROTOCOL_VERSIONS.include?(@protocol_version)

      raise Error.new(
        UNSUPPORTED_PROTOCOL_VERSION,
        "Unsupported protocol version: #{@protocol_version}",
        data: {'supported' => Config::SUPPORTED_PROTOCOL_VERSIONS}
      )
    end

    # Só a era moderna carrega metadados por requisição. Exigi-los de um cliente
    # antigo o barraria sem motivo.
    def validate_meta!
      return unless modern?
      return if @method_name == 'initialize'

      if @meta[META_VERSION].blank?
        raise Error.new(INVALID_PARAMS, "_meta.#{META_VERSION} is required")
      end
      return if @meta.key?(META_CAPABILITIES)

      raise Error.new(INVALID_PARAMS, "_meta.#{META_CAPABILITIES} is required")
    end

    def validate_mirrored_headers!
      return unless modern?

      # MCP-Protocol-Version x _meta
      if (h = header('MCP-Protocol-Version')) && @meta[META_VERSION].present? && h != @meta[META_VERSION]
        mismatch!('MCP-Protocol-Version', h, @meta[META_VERSION])
      end

      validate_header_against!('Mcp-Method', @method_name)

      key = NAMED_METHODS[@method_name]
      return unless key

      validate_header_against!('Mcp-Name', @params[key].to_s, decode: true)
    end

    def validate_header_against!(header_name, body_value, decode: false)
      raw = header(header_name)
      if raw.nil?
        raise Error.new(HEADER_MISMATCH, "Missing required header #{header_name}")
      end

      value = decode ? self.class.decode_header(raw) : raw
      return if value == body_value

      mismatch!(header_name, value, body_value)
    end

    def mismatch!(header_name, header_value, body_value)
      raise Error.new(
        HEADER_MISMATCH,
        "Header mismatch: #{header_name} header value '#{header_value}' " \
        "does not match body value '#{body_value}'"
      )
    end
  end
end
