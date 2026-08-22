# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    class ListTimeEntries < Base
      def self.permission = :view_time_entries

      def self.description
        'List logged time entries you are allowed to see.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'project' => {'type' => 'string'},
            'issue_id' => {'type' => 'integer'},
            'mine_only' => {'type' => 'boolean'},
            'from' => {'type' => 'string', 'description' => 'ISO date, inclusive'},
            'to' => {'type' => 'string', 'description' => 'ISO date, inclusive'},
            'limit' => {'type' => 'integer'},
            'offset' => {'type' => 'integer'}
          },
          'additionalProperties' => false
        }
      end

      def call(arguments)
        offset, limit = paginate(arguments)
        scope = TimeEntry.visible(user).order(spent_on: :desc, id: :desc)
        scope = scope.where(project_id: find_project!(arguments['project']).id) if arguments['project'].present?
        scope = scope.where(issue_id: find_issue!(arguments['issue_id']).id) if arguments['issue_id'].present?
        scope = scope.where(user_id: user.id) if arguments['mine_only']
        scope = scope.where(spent_on: Date.parse(arguments['from'])..) if arguments['from'].present?
        scope = scope.where(spent_on: ..Date.parse(arguments['to'])) if arguments['to'].present?

        total = scope.count
        hours = scope.sum(:hours)
        entries = scope.offset(offset).limit(limit).to_a

        structured = {
          'total_count' => total, 'total_hours' => hours.to_f,
          'offset' => offset, 'limit' => limit,
          'time_entries' => entries.map { |t| Presenter.time_entry(t) }
        }
        result("#{total} entr(ies), #{hours.to_f}h total.", structured)
      rescue Date::Error
        fail!('from and to must be ISO dates, e.g. 2026-08-01')
      end
    end
  end
end
