# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    class GetProject < Base
      def self.permission = :view_project

      def self.description
        'Get one project, with the trackers and modules enabled on it.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {'project' => {'type' => 'string', 'description' => 'Identifier or numeric id'}},
          'required' => ['project'],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        project = find_project!(arguments['project'])
        data = Presenter.project(project).merge(
          'trackers' => project.trackers.map { |t| Presenter.named(t) },
          'enabled_modules' => project.enabled_module_names.sort,
          'you_can' => permissions_summary(project)
        )
        result("#{project.name} (#{project.identifier})\n#{project.description}", data)
      end

      private

      # Diz ao modelo o que ele pode fazer aqui, para não tentar o que vai falhar.
      def permissions_summary(project)
        %i[add_issues edit_issues add_issue_notes log_time view_time_entries view_wiki_pages]
          .select { |p| user.allowed_to?(p, project) }
          .map(&:to_s)
      end
    end
  end
end
