# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Cria uma tarefa, pelo mesmo caminho do MailHandler (app/models/mail_handler.rb),
    # que é o precedente do core para escrever como um usuário fora de controller:
    # checa project.allows_to? E user.allowed_to?, depois safe_attributes= e save.
    #
    # `safe_attributes=` não é um filtro ingênuo — ele valida projeto, tracker e
    # status contra o que o usuário pode escolher (app/models/issue.rb:574-651).
    # Por isso os atributos passam por ele, e nunca por assign_attributes.
    class CreateIssue < Base
      def self.permission = :add_issues

      def self.description
        'Create an issue in a project. Only fields you are allowed to set are applied. ' \
        'Returns the created issue with its id and URL.'
      end

      def self.annotations
        {'readOnlyHint' => false, 'destructiveHint' => false, 'idempotentHint' => false,
         'openWorldHint' => false}
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'project' => {'type' => 'string', 'description' => 'Project identifier or numeric id'},
            'subject' => {'type' => 'string'},
            'description' => {'type' => 'string'},
            'tracker_id' => {'type' => 'integer', 'description' => 'See list_trackers'},
            'priority_id' => {'type' => 'integer', 'description' => 'See list_priorities'},
            'assigned_to_id' => {'type' => 'integer', 'description' => 'User id; use "me" via assign_to_me instead'},
            'assign_to_me' => {'type' => 'boolean'},
            'parent_issue_id' => {'type' => 'integer'},
            'start_date' => {'type' => 'string', 'description' => 'ISO date'},
            'due_date' => {'type' => 'string', 'description' => 'ISO date'},
            'estimated_hours' => {'type' => 'number'}
          },
          'required' => %w[project subject],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        project = find_project!(arguments['project'])
        # Duas checagens distintas, como o MailHandler faz: a do projeto cobre
        # módulo desabilitado / projeto fechado ou arquivado; a do usuário cobre
        # papel e escopo OAuth.
        fail!("Issue tracking is not available on project '#{project.identifier}'") unless project.allows_to?(:add_issues)
        require_permission!(:add_issues, project)

        issue = Issue.new(project: project, author: user)
        issue.tracker ||= issue.allowed_target_trackers(user).first
        fail!('No tracker available to you in this project') if issue.tracker.nil?

        issue.safe_attributes = attributes_from(arguments, issue)
        unless issue.save
          fail!("Could not create the issue: #{issue.errors.full_messages.join('; ')}")
        end

        data = Presenter.issue(issue, detailed: true)
        result("Created ##{issue.id} — #{issue.subject}\n#{data['url']}", data)
      end

      private

      def attributes_from(arguments, issue)
        attrs = arguments.slice('subject', 'description', 'tracker_id', 'priority_id',
                                'parent_issue_id', 'start_date', 'due_date', 'estimated_hours')
        attrs['assigned_to_id'] = user.id if arguments['assign_to_me']
        attrs['assigned_to_id'] ||= arguments['assigned_to_id'] if arguments['assigned_to_id']
        # Defaults que o IssuesController aplica em build_new_issue_from_params.
        if attrs['start_date'].blank? && Setting.default_issue_start_date_to_creation_date?
          attrs['start_date'] = User.current.today
        end
        attrs.compact_blank!
        attrs['tracker_id'] ||= issue.tracker&.id
        attrs
      end
    end
  end
end
