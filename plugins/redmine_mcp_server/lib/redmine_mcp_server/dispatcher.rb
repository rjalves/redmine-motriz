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
        # HTTP 200, não 404. "Método não encontrado" é erro de PROTOCOLO: o
        # transporte funcionou e a resposta é um JSON-RPC error perfeitamente
        # válido. O status HTTP no transporte do MCP só descreve falhas de
        # transporte (400 malformado, 401, 403, 405).
        #
        # Isto não é purismo. O conector do Claude sonda `server/discover`
        # (revisão 2026-07-28) em paralelo com `initialize`, contando com a
        # recusa para cair no handshake antigo. Um 404 nessa sonda é lido como
        # "esta URL não é um servidor MCP" — que é, palavra por palavra, o erro
        # que o usuário via.
        raise Envelope::Error.new(
          Envelope::METHOD_NOT_FOUND,
          "Method not found: #{@envelope.method_name}",
          http_status: 200
        )
      end
    end

    private

    # A era moderna não exige handshake, mas clientes anteriores ainda mandam
    # initialize antes de tudo. Responder é barato e evita travar esses clientes.
    def initialize_result
      complete(
        'protocolVersion' => negotiated_version,
        'capabilities' => {'tools' => {'listChanged' => false}},
        'serverInfo' => SERVER_INFO,
        'instructions' => instructions
      )
    end

    # No handshake quem propõe a versão é `params.protocolVersion`, não o
    # cabeçalho de transporte — e os dois divergem na prática: o Claude manda
    # `initialize` com params.protocolVersion=2025-11-25 enquanto anuncia
    # 2026-07-28 no envelope. Ecoar a versão do cabeçalho responderia ao cliente
    # uma versão que ele não ofereceu.
    def negotiated_version
      proposed = @envelope.params['protocolVersion'].to_s
      return proposed if Config::SUPPORTED_PROTOCOL_VERSIONS.include?(proposed)

      @envelope.protocol_version
    end

    # O texto abaixo carrega um aviso que parece redundante e não é: sem ele um
    # assistente lê a lista curta e conclui, de boa-fé, que o servidor não sabe
    # editar tarefas — foi exatamente o que aconteceu em produção. A lista é
    # filtrada por permissão ANTES de ele vê-la, então ausência de ferramenta é
    # indistinguível de ausência de funcionalidade, a menos que se diga.
    def instructions
      'This server exposes the Redmine instance at ' \
      "#{Config.base_url}. Every tool runs as the authenticated user and " \
      'respects their Redmine permissions, so a tool may legitimately refuse. ' \
      "\n\n" \
      'IMPORTANT: the tool list is filtered by your Redmine permissions — a ' \
      'tool you are not allowed to use is not listed at all. So a missing ' \
      'capability means a missing permission, not a missing feature. This ' \
      'server always implements: update_issue (needs edit_issues) and ' \
      'log_time (needs log_time). If either is absent from your tool list, ' \
      'the account lacks that permission in every project — say so and ' \
      'suggest asking a Redmine administrator, rather than reporting that ' \
      'the server cannot do it. A frequent cause: an administrator account ' \
      'that belongs to no project, because an OAuth token without the admin ' \
      'scope drops the administrator bypass and falls back to the ' \
      'Non-member role. ' \
      "\n\n" \
      'Call list_enumerations before creating or updating an issue when you ' \
      'need tracker, status or priority ids, and list_members to turn a ' \
      "person's name into the assigned_to_id those tools expect."
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

    # `resultType` é campo da era 2026-07-28. Mandá-lo para um cliente que
    # negociou 2025-11-25 é devolver um campo de uma revisão que ele não pediu
    # — inofensivo se ele ignorar campos extras, quebra se ele validar estrito.
    # Não há motivo para correr esse risco.
    def complete(payload)
      return payload unless @envelope.modern?

      {'resultType' => 'complete'}.merge(payload)
    end
  end
end
