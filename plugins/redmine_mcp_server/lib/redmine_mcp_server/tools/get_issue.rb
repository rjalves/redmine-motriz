# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    class GetIssue < Base
      def self.permission = :view_issues

      def self.description
        'Get one issue in full: description, attributes and the comment history ' \
        'visible to you. Private notes are included only if you have the ' \
        'view_private_notes permission on the project.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {'id' => {'type' => 'integer', 'description' => 'Issue id'}},
          'required' => ['id'],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        issue = find_issue!(arguments['id'])
        data = Presenter.issue(issue, detailed: true)
        result(text_for(issue, data), data)
      end

      private

      def text_for(issue, data)
        parts = ["##{issue.id} #{issue.subject}",
                 "Project: #{issue.project.name} | Tracker: #{issue.tracker} | " \
                 "Status: #{issue.status} | Priority: #{issue.priority}"]
        parts << "Assigned to: #{issue.assigned_to}" if issue.assigned_to
        parts << "\n#{issue.description}" if issue.description.present?
        notes = data['journals'].to_a
        parts << "\n#{notes.size} comment(s)." if notes.any?
        parts.join("\n")
      end
    end
  end
end
