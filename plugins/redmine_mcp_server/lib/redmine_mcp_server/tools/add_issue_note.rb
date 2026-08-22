# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    class AddIssueNote < Base
      def self.permission = :add_issue_notes

      def self.description
        'Add a comment to an issue without changing any of its attributes.'
      end

      def self.annotations
        {'readOnlyHint' => false, 'destructiveHint' => false, 'idempotentHint' => false,
         'openWorldHint' => false}
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'id' => {'type' => 'integer'},
            'notes' => {'type' => 'string'},
            'private' => {'type' => 'boolean',
                          'description' => 'Requires the set_notes_private permission'}
          },
          'required' => %w[id notes],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        issue = find_issue!(arguments['id'])
        fail!("You cannot comment on issue ##{issue.id}") unless issue.notes_addable?(user)
        fail!('notes must not be empty') if arguments['notes'].to_s.strip.empty?

        issue.init_journal(user, arguments['notes'].to_s)

        if arguments['private']
          unless user.allowed_to?(:set_notes_private, issue.project)
            fail!('You do not have the set_notes_private permission on this project')
          end
          issue.current_journal.private_notes = true
        end

        unless issue.save
          fail!("Could not add the note: #{issue.errors.full_messages.join('; ')}")
        end

        journal = issue.current_journal
        result("Comment added to ##{issue.id}.",
               {'issue_id' => issue.id, 'journal_id' => journal&.id,
                'private' => !!journal&.private_notes,
                'url' => Presenter.url_for("/issues/#{issue.id}")})
      end
    end
  end
end
