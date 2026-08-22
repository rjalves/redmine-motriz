# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Busca textual global, sobre o Redmine::Search::Fetcher.
    #
    # Pegadinha verificada no core (lib/redmine/search.rb:110-124): o Fetcher
    # guarda o usuário passado no construtor, mas em load_result_ids usa
    # `User.current`. Ou seja, quem manda é o User.current — que o
    # ApplicationController já setou com o escopo OAuth aplicado. Passamos o
    # mesmo objeto nos dois lugares para não haver divergência.
    class Search < Base
      def self.permission = :search_project

      TYPES = %w[issues news documents changesets wiki_pages messages projects].freeze

      def self.description
        'Full-text search across issues, wiki pages, news, documents and projects. ' \
        'Returns matches you are allowed to see. Prefer list_issues when you can ' \
        'express the need as a filter — it is more precise.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'query' => {'type' => 'string', 'description' => 'Search terms. At most 5 are used.'},
            'project' => {'type' => 'string', 'description' => 'Restrict to one project (identifier or id)'},
            'types' => {'type' => 'array', 'items' => {'type' => 'string', 'enum' => TYPES},
                        'description' => "Defaults to all of: #{TYPES.join(', ')}"},
            'titles_only' => {'type' => 'boolean'},
            'open_issues_only' => {'type' => 'boolean'},
            'limit' => {'type' => 'integer', 'description' => '1-100, defaults to 25'},
            'offset' => {'type' => 'integer'}
          },
          'required' => ['query'],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        question = arguments['query'].to_s.strip
        fail!('query must not be empty') if question.empty?

        offset, limit = paginate(arguments)
        project = arguments['project'].present? ? find_project!(arguments['project']) : nil
        types = Array(arguments['types']).presence || TYPES
        types &= ::Redmine::Search.available_search_types

        fetcher = ::Redmine::Search::Fetcher.new(
          question, user, types, project ? [project] : nil,
          titles_only: !!arguments['titles_only'],
          open_issues: !!arguments['open_issues_only'],
          all_words: true
        )

        total = fetcher.result_count
        results = fetcher.results(offset, limit)
        structured = {
          'total_count' => total, 'offset' => offset, 'limit' => limit,
          'results' => results.map { |r| present(r) }
        }
        result(summary(total, results), structured)
      end

      private

      def present(record)
        {
          'type' => record.class.name.underscore,
          'id' => record.id,
          'title' => record.respond_to?(:event_title) ? record.event_title : record.to_s,
          'datetime' => (record.event_datetime.utc.iso8601 if record.respond_to?(:event_datetime)),
          'project' => Presenter.named(record.try(:project))
        }.compact
      end

      def summary(total, results)
        return 'No results.' if results.empty?

        (["#{total} result(s):"] + results.map { |r| present(r).values_at('type', 'id', 'title').join(' ') }).join("\n")
      end
    end
  end
end
