# frozen_string_literal: true

module RedmineMcpServer
  # Roteia o método JSON-RPC já validado pelo Envelope.
  #
  # Devolve sempre o objeto `result` do JSON-RPC, ou levanta Envelope::Error
  # para erro de protocolo. Erro de execução de ferramenta NÃO é exceção de
  # protocolo: vira um result com isError: true, que o modelo lê e usa para se
  # corrigir (é a distinção que a especificação faz em "Error Handling").
  class Dispatcher
    SERVER_INFO = {'name' => 'redmine-mcp-server', 'version' => '0.1.0'}.freeze

    def initialize(user, envelope)
      @user = user
      @envelope = envelope
    end

    def call
      case @envelope.method_name
      when 'initialize'      then initialize_result
      when 'ping'            then complete({})
      when 'tools/list'      then tools_list
      when 'tools/call'      then tools_call
      else
        raise Envelope::Error.new(
          Envelope::METHOD_NOT_FOUND,
          "Method not found: #{@envelope.method_name}",
          http_status: 404
        )
      end
    end

    private

    # A era moderna não exige handshake, mas clientes anteriores ainda mandam
    # initialize antes de tudo. Responder é barato e evita travar esses clientes.
    def initialize_result
      complete(
        'protocolVersion' => @envelope.protocol_version,
        'capabilities' => {'tools' => {'listChanged' => false}},
        'serverInfo' => SERVER_INFO,
        'instructions' => instructions
      )
    end

    def instructions
        'This server exposes the Redmine instance at ' \
        "#{Config.base_url}. Every tool runs as the authenticated user and " \
        'respects their Redmine permissions, so a tool may legitimately refuse. ' \
        'Call list_enumerations before creating or updating an issue when you ' \
        'need tracker, status or priority ids.'
    end

    def tools_list
      complete('tools' => Registry.definitions_for(@user))
    end

    def tools_call
      name = @envelope.params['name'].to_s
      tool = Registry.resolve(name, @user)

      # Ferramenta inexistente e ferramenta sem permissão dão a mesma resposta:
      # distinguir revelaria quais ferramentas existem para outros usuários.
      if tool.nil?
        raise Envelope::Error.new(Envelope::INVALID_PARAMS, "Unknown tool: #{name}")
      end

      allowed, remaining = Throttle.hit(@user.id)
      unless allowed
        return execution_error(
          "Rate limit exceeded (#{Config.rate_limit} calls/minute). Wait a moment before retrying."
        )
      end

      arguments = @envelope.params['arguments']
      arguments = {} unless arguments.is_a?(Hash)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        outcome = tool.new(@user).call(arguments)
        audit(tool, arguments, outcome, started, nil)
        complete(outcome.to_h.merge('_meta' => {'io.modelcontextprotocol/serverInfo' => SERVER_INFO,
                                                'rateLimitRemaining' => remaining}))
      rescue Tools::Base::ExecutionError => e
        audit(tool, arguments, nil, started, e.message)
        execution_error(e.message)
      rescue StandardError => e
        # Erro inesperado não pode virar 500 com stack trace na cara do modelo,
        # nem vazar detalhe interno. Log completo, mensagem genérica.
        Rails.logger.error("MCP tool #{tool.tool_name} failed: #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace&.first(10)&.join("\n"))
        audit(tool, arguments, nil, started, e.class.name)
        execution_error('The tool failed unexpectedly. The error was logged on the server.')
      end
    end

    def audit(tool, arguments, outcome, started, error)
      McpToolCall.record!(
        user: @user,
        tool_name: tool.tool_name,
        argument_keys: arguments.keys,
        structured: outcome&.structured,
        error: error,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      )
    rescue StandardError => e
      # Auditoria nunca derruba a chamada.
      Rails.logger.error("MCP audit failed: #{e.class}: #{e.message}")
    end

    def execution_error(message)
      complete('content' => [{'type' => 'text', 'text' => message}], 'isError' => true)
    end

    # Todo result da era 2026-07-28 carrega resultType.
    def complete(payload)
      {'resultType' => 'complete'}.merge(payload)
    end
  end
end
