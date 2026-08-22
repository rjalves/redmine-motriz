# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Busca de tarefas via IssueQuery — o mesmo motor das telas de listagem.
    #
    # IssueQuery#base_scope (app/models/issue_query.rb:375) já é
    # `Issue.visible.…`, que resolve pelo User.current. Não há filtro de
    # permissão a escrever aqui: montar a query errada é o único jeito de
    # vazar dado.
    class ListIssues < Base
      def self.permission = :view_issues

      def self.description
        'Search issues with filters. Returns a paginated list. ' \
        'Use get_issue for the full description and comment history of one issue.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'project' => {'type' => 'string', 'description' => 'Project identifier or numeric id'},
            'status' => {'type' => 'string', 'enum' => %w[open closed all],
                         'description' => 'Defaults to open'},
            'assigned_to_me' => {'type' => 'boolean'},
            'author_is_me' => {'type' => 'boolean'},
            'tracker_id' => {'type' => 'integer'},
            'query' => {'type' => 'string', 'description' => 'Free text matched against subject and description'},
            'updated_after' => {'type' => 'string', 'description' => 'ISO date, e.g. 2026-08-01'},
            'sort' => {'type' => 'string', 'enum' => %w[updated_on created_on priority due_date id],
                       'description' => 'Defaults to updated_on, descending'},
            'limit' => {'type' => 'integer', 'description' => '1-100, defaults to 25'},
            'offset' => {'type' => 'integer'}
          },
          'additionalProperties' => false
        }
      end

      def self.output_schema
        {
          'type' => 'object',
          'properties' => {
            'total_count' => {'type' => 'integer'},
            'offset' => {'type' => 'integer'},
            'limit' => {'type' => 'integer'},
            'issues' => {'type' => 'array', 'items' => {'type' => 'object'}}
          },
          'required' => %w[total_count issues]
        }
      end

      def call(arguments)
        offset, limit = paginate(arguments)
        query = build_query(arguments)
        fail!("Invalid filters: #{query.errors.full_messages.join(', ')}") unless query.valid?

        total = query.issue_count
        issues = query.issues(offset: offset, limit: limit,
                              order: "#{sort_column(arguments)} DESC")

        structured = {
          'total_count' => total, 'offset' => offset, 'limit' => limit,
          'issues' => issues.map { |i| Presenter.issue(i) }
        }
        result(summary(total, offset, issues), structured)
      rescue ::Query::StatementInvalid, ::Query::QueryError => e
        fail!("Query error: #{e.message}")
      end

      private

      def build_query(arguments)
        project = arguments['project'].present? ? find_project!(arguments['project']) : nil
        # name "_" é exigido: Query valida presença de nome mesmo em query ad-hoc
        # (ver QueriesHelper#retrieve_query).
        query = IssueQuery.new(name: '_', project: project)
        query.add_filter('status_id', status_operator(arguments), [])
        query.add_filter('assigned_to_id', '=', ['me']) if arguments['assigned_to_me']
        query.add_filter('author_id', '=', ['me']) if arguments['author_is_me']
        query.add_filter('tracker_id', '=', [arguments['tracker_id'].to_s]) if arguments['tracker_id']
        query.add_filter('subject', '~', [arguments['query']]) if arguments['query'].present?
        if arguments['updated_after'].present?
          query.add_filter('updated_on', '>=', [arguments['updated_after']])
        end
        query
      end

      def status_operator(arguments)
        case arguments['status'].to_s
        when 'closed' then 'c'
        when 'all' then '*'
        else 'o'
        end
      end

      def sort_column(arguments)
        allowed = %w[updated_on created_on id due_date]
        column = arguments['sort'].to_s
        return "#{Issue.table_name}.#{column}" if allowed.include?(column)
        return 'issues.priority_id' if column == 'priority'

        "#{Issue.table_name}.updated_on"
      end

      def summary(total, offset, issues)
        return 'No issues matched.' if issues.empty?

        lines = issues.map do |i|
          "##{i.id} [#{i.status}] #{i.subject} (#{i.project.name}" \
          "#{i.assigned_to ? ", assigned to #{i.assigned_to}" : ''})"
        end
        header = "#{total} issue(s) matched, showing #{offset + 1}-#{offset + issues.size}:"
        ([header] + lines).join("\n")
      end
    end
  end
end
