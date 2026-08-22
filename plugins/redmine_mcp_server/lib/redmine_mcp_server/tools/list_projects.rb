# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    class ListProjects < Base
      def self.permission = :view_project

      def self.description
        'List the projects you can see. Use the returned identifier with the other tools.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'query' => {'type' => 'string', 'description' => 'Filter by name or identifier'},
            'limit' => {'type' => 'integer', 'description' => '1-100, defaults to 25'},
            'offset' => {'type' => 'integer'}
          },
          'additionalProperties' => false
        }
      end

      def call(arguments)
        offset, limit = paginate(arguments)
        scope = Project.visible(user).active.order(:lft)
        if arguments['query'].present?
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(arguments['query'].to_s)}%"
          scope = scope.where('LOWER(projects.name) LIKE LOWER(:q) OR LOWER(projects.identifier) LIKE LOWER(:q)',
                              q: pattern)
        end
        total = scope.count
        projects = scope.offset(offset).limit(limit).to_a

        structured = {
          'total_count' => total, 'offset' => offset, 'limit' => limit,
          'projects' => projects.map { |p| Presenter.project(p) }
        }
        text = projects.empty? ? 'No projects matched.' : projects.map { |p| "#{p.identifier} — #{p.name}" }.join("\n")
        result(text, structured)
      end
    end
  end
end
