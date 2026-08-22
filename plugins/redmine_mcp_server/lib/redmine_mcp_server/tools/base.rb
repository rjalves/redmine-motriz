# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Base de toda ferramenta.
    #
    # Cada subclasse declara o nome, o schema e — o que mais importa — a
    # permissão do Redmine que exige. O Registry usa essa permissão tanto para
    # esconder a ferramenta de quem não pode usá-la quanto para barrar a chamada.
    class Base
      # Erro de execução: vira um resultado com isError: true, que o modelo lê e
      # usa para se corrigir. Difere de erro de protocolo, que é JSON-RPC error.
      class ExecutionError < StandardError; end

      class << self
        def tool_name
          name.demodulize.underscore
        end

        # Permissão do Redmine exigida. nil = disponível a qualquer usuário
        # autenticado (usada só pelas listas de enumeração).
        def permission
          nil
        end

        def title = nil
        def description = ''
        def input_schema = {'type' => 'object', 'additionalProperties' => false}
        def output_schema = nil

        # Anotações da especificação. São a primeira linha da aprovação humana:
        # o cliente as usa para decidir o quanto insistir antes de executar.
        def annotations
          {'readOnlyHint' => true, 'destructiveHint' => false, 'idempotentHint' => true}
        end

        def definition
          d = {
            'name' => tool_name,
            'description' => description,
            'inputSchema' => input_schema,
            'annotations' => annotations
          }
          d['title'] = title if title
          d['outputSchema'] = output_schema if output_schema
          d
        end

        # Disponível para este usuário? Sem contexto de projeto, a pergunta é
        # global: existe algum projeto onde ele poderia usar isto?
        def available_to?(user)
          return false unless user&.logged?
          return true if permission.nil?

          user.allowed_to?(permission, nil, global: true)
        end
      end

      def initialize(user)
        @user = user
      end

      def call(_arguments)
        raise NotImplementedError
      end

      private

      attr_reader :user

      def fail!(message)
        raise ExecutionError, message
      end

      # Teto igual ao da API REST do Redmine (application_controller.rb:675-696):
      # default 25, máximo 100. Não faz sentido o MCP ser mais generoso.
      def paginate(arguments)
        limit = arguments['limit'].to_i
        limit = 25 if limit < 1
        limit = 100 if limit > 100
        offset = arguments['offset'].to_i
        offset = 0 if offset.negative?
        [offset, limit]
      end

      def find_project!(identifier)
        project = Project.find_by(identifier: identifier.to_s) ||
                  Project.find_by(id: identifier.to_s.to_i)
        fail!("Project not found: #{identifier}") unless project&.visible?(user)
        project
      end

      def find_issue!(id)
        issue = Issue.find_by(id: id.to_i)
        # Mensagem igual para inexistente e invisível: dizer "existe mas você não
        # pode ver" já é vazar informação.
        fail!("Issue not found or not visible: ##{id}") unless issue&.visible?(user)
        issue
      end

      def require_permission!(permission, project)
        return if user.allowed_to?(permission, project)

        fail!("You do not have the '#{permission}' permission on project '#{project.identifier}'")
      end

      def result(text, structured = nil)
        Result.new(text, structured)
      end

      # Um resultado de ferramenta. `structuredContent` é o dado; o bloco de
      # texto é a versão serializada, que a especificação recomenda manter por
      # compatibilidade.
      Result = Struct.new(:text, :structured) do
        def to_h
          h = {'content' => [{'type' => 'text', 'text' => text.to_s}], 'isError' => false}
          h['structuredContent'] = structured unless structured.nil?
          h
        end
      end
    end
  end
end
