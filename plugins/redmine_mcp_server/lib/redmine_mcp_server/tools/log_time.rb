# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Aponta horas. TimeEntry#safe_attributes= já valida sozinho que a tarefa é
    # visível e que apontar para outra pessoa exige :log_time_for_other_users —
    # não replicamos essas checagens aqui.
    class LogTime < Base
      def self.permission = :log_time

      def self.description
        'Log spent time on a project or an issue, for yourself.'
      end

      def self.annotations
        {'readOnlyHint' => false, 'destructiveHint' => false, 'idempotentHint' => false,
         'openWorldHint' => false}
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'issue_id' => {'type' => 'integer', 'description' => 'Either issue_id or project'},
            'project' => {'type' => 'string', 'description' => 'Project identifier or numeric id'},
            'hours' => {'type' => 'number', 'description' => 'Decimal hours, e.g. 1.5'},
            'spent_on' => {'type' => 'string', 'description' => 'ISO date, defaults to today'},
            'comments' => {'type' => 'string'},
            'activity_id' => {'type' => 'integer', 'description' => 'See list_time_entry_activities'}
          },
          'required' => ['hours'],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        issue = arguments['issue_id'].present? ? find_issue!(arguments['issue_id']) : nil
        project = issue&.project
        project ||= find_project!(arguments['project']) if arguments['project'].present?
        fail!('Provide either issue_id or project') if project.nil?

        fail!("Time tracking is not available on project '#{project.identifier}'") unless project.allows_to?(:log_time)
        require_permission!(:log_time, project)
        fail!('hours must be greater than zero') unless arguments['hours'].to_f.positive?

        entry = TimeEntry.new(project: project, issue: issue, author: user, user: user,
                              spent_on: user.today)
        entry.safe_attributes = arguments.slice('hours', 'comments', 'spent_on', 'activity_id').compact

        unless entry.save
          fail!("Could not log time: #{entry.errors.full_messages.join('; ')}")
        end

        data = Presenter.time_entry(entry)
        target = issue ? "issue ##{issue.id}" : "project #{project.identifier}"
        result("Logged #{entry.hours}h on #{target} (#{entry.spent_on}).", data)
      end
    end
  end
end
