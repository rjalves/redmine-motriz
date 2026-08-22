# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    class GetWikiPage < Base
      def self.permission = :view_wiki_pages

      def self.description
        'Read a wiki page from a project. Omit the title to get the project wiki start page.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'project' => {'type' => 'string'},
            'title' => {'type' => 'string', 'description' => 'Defaults to the wiki start page'}
          },
          'required' => ['project'],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        project = find_project!(arguments['project'])
        require_permission!(:view_wiki_pages, project)

        wiki = project.wiki
        fail!("Project '#{project.identifier}' has no wiki") if wiki.nil?

        title = arguments['title'].presence || wiki.start_page
        page = wiki.find_page(title)
        fail!("Wiki page not found: #{title}") if page.nil?
        fail!("Wiki page not visible: #{title}") unless page.visible?(user)

        data = Presenter.wiki_page(page, page.content)
        result("#{page.title}\n\n#{page.content&.text}", data)
      end
    end
  end
end
