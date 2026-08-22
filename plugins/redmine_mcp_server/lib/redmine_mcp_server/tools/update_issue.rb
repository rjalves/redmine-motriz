# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Atualiza atributos de uma tarefa.
    #
    # destructiveHint: true — sobrescreve valores existentes. É a anotação que
    # faz o cliente de IA insistir mais na confirmação antes de executar.
    class UpdateIssue < Base
      def self.permission = :edit_issues

      def self.description
        'Update attributes of an existing issue (status, assignee, dates, subject…). ' \
        'Overwrites the current values. To only add a comment, use add_issue_note instead.'
      end

      def self.annotations
        {'readOnlyHint' => false, 'destructiveHint' => true, 'idempotentHint' => false,
         'openWorldHint' => false}
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'id' => {'type' => 'integer'},
            'subject' => {'type' => 'string'},
            'description' => {'type' => 'string'},
            'status_id' => {'type' => 'integer', 'description' => 'See list_issue_statuses'},
            'priority_id' => {'type' => 'integer'},
            'assigned_to_id' => {'type' => 'integer'},
            'assign_to_me' => {'type' => 'boolean'},
            'done_ratio' => {'type' => 'integer', 'description' => '0-100'},
            'start_date' => {'type' => 'string'},
            'due_date' => {'type' => 'string'},
            'estimated_hours' => {'type' => 'number'},
            'notes' => {'type' => 'string', 'description' => 'Optional comment describing the change'}
          },
          'required' => ['id'],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        issue = find_issue!(arguments['id'])
        fail!("You cannot edit issue ##{issue.id}") unless issue.attributes_editable?(user)

        # init_journal ANTES do save. Sem isso não há histórico nem notificação —
        # create_journal é um after_save que só age se current_journal existir
        # (app/models/issue.rb:890-892, 2058-2062).
        issue.init_journal(user, arguments['notes'].to_s)

        attrs = arguments.except('id', 'notes', 'assign_to_me')
        attrs['assigned_to_id'] = user.id if arguments['assign_to_me']
        issue.safe_attributes = attrs.compact

        unless issue.save
          fail!("Could not update the issue: #{issue.errors.full_messages.join('; ')}")
        end

        changed = issue.current_journal&.details&.map(&:prop_key) || []
        data = Presenter.issue(issue.reload, detailed: true)
        result("Updated ##{issue.id}#{changed.any? ? " (changed: #{changed.join(', ')})" : ''}", data)
      end
    end
  end
end
