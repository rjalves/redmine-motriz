# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Uma ferramenta só para as listas de referência (trackers, situações,
    # prioridades, atividades). Separá-las em quatro só encheria o catálogo:
    # o modelo precisa dos ids antes de escrever, e vai querer mais de uma lista
    # na mesma tacada.
    #
    # Não exige permissão: são metadados de configuração, os mesmos que qualquer
    # formulário de tarefa já mostra. Nenhum dado de projeto vaza por aqui.
    class ListEnumerations < Base
      def self.permission = nil

      def self.description
        'List the reference values needed to create or update issues: trackers, ' \
        'issue statuses, priorities and time-entry activities. Call this before ' \
        'create_issue or update_issue if you need an id.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'kinds' => {
              'type' => 'array',
              'items' => {'type' => 'string',
                          'enum' => %w[trackers issue_statuses priorities activities]},
              'description' => 'Defaults to all of them'
            },
            'project' => {'type' => 'string',
                          'description' => 'Restrict trackers to those enabled on this project'}
          },
          'additionalProperties' => false
        }
      end

      def call(arguments)
        kinds = Array(arguments['kinds']).presence || %w[trackers issue_statuses priorities activities]
        project = arguments['project'].present? ? find_project!(arguments['project']) : nil

        data = {}
        data['trackers'] = trackers(project).map { |t| Presenter.named(t) } if kinds.include?('trackers')
        if kinds.include?('issue_statuses')
          data['issue_statuses'] = IssueStatus.sorted.map do |s|
            Presenter.named(s).merge('is_closed' => s.is_closed)
          end
        end
        data['priorities'] = IssuePriority.active.map { |p| Presenter.named(p) } if kinds.include?('priorities')
        if kinds.include?('activities')
          activities = project ? project.activities : TimeEntryActivity.shared.active
          data['activities'] = activities.map { |a| Presenter.named(a) }
        end

        result(data.map { |k, v| "#{k}: #{v.map { |e| "#{e['id']}=#{e['name']}" }.join(', ')}" }.join("\n"), data)
      end

      private

      def trackers(project)
        project ? project.trackers.sorted : Tracker.sorted
      end
    end
  end
end
