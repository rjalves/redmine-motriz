# frozen_string_literal: true

module RedmineMcpServer
  # Converte objetos do Redmine em hashes para o MCP.
  #
  # Montado à mão de propósito, em vez de reaproveitar os templates .api.rsb via
  # WebhookPayload::ApiRenderer: aquele renderizador faz `User.current = user`
  # com um User recém-carregado, cujo @oauth_scope é nil — o que desligaria o
  # filtro de escopo OAuth dentro do template.
  module Presenter
    PROJECT_STATUS = {
      Project::STATUS_ACTIVE => 'active',
      Project::STATUS_CLOSED => 'closed',
      Project::STATUS_ARCHIVED => 'archived',
      Project::STATUS_SCHEDULED_FOR_DELETION => 'scheduled_for_deletion'
    }.freeze

    module_function

    def project(p)
      {
        'id' => p.id,
        'identifier' => p.identifier,
        'name' => p.name,
        'description' => p.description.presence,
        'status' => PROJECT_STATUS[p.status] || p.status.to_s,
        'parent_id' => p.parent_id,
        'url' => url_for("/projects/#{p.identifier}")
      }.compact
    end

    def issue(i, detailed: false)
      h = {
        'id' => i.id,
        'subject' => i.subject,
        'project' => {'id' => i.project_id, 'identifier' => i.project&.identifier, 'name' => i.project&.name},
        'tracker' => named(i.tracker),
        'status' => named(i.status),
        'priority' => named(i.priority),
        'author' => named(i.author),
        'assigned_to' => named(i.assigned_to),
        'fixed_version' => named(i.fixed_version),
        'start_date' => i.start_date&.to_s,
        'due_date' => i.due_date&.to_s,
        'done_ratio' => i.done_ratio,
        'estimated_hours' => i.estimated_hours,
        'is_private' => i.is_private,
        'parent_id' => i.parent_id,
        'created_on' => i.created_on&.utc&.iso8601,
        'updated_on' => i.updated_on&.utc&.iso8601,
        'url' => url_for("/issues/#{i.id}")
      }
      if detailed
        h['description'] = i.description.presence
        h['journals'] = journals(i)
      end
      h.compact
    end

    def time_entry(t)
      {
        'id' => t.id,
        'project' => named(t.project),
        'issue_id' => t.issue_id,
        'user' => named(t.user),
        'activity' => named(t.activity),
        'hours' => t.hours,
        'comments' => t.comments.presence,
        'spent_on' => t.spent_on&.to_s
      }.compact
    end

    def wiki_page(page, content)
      {
        'title' => page.title,
        'project' => named(page.project),
        'version' => content&.version,
        'text' => content&.text,
        'updated_on' => content&.updated_on&.utc&.iso8601,
        'url' => url_for("/projects/#{page.project.identifier}/wiki/#{page.title}")
      }.compact
    end

    def named(obj)
      return nil if obj.nil?

      {'id' => obj.id, 'name' => obj.respond_to?(:name) ? obj.name : obj.to_s}
    end

    # Usa Issue#visible_journals_with_index (app/models/issue.rb:933), que é o
    # mesmo método do IssuesController#show.
    #
    # Cuidado que custou uma correção: Journal#visible? NÃO filtra nota privada —
    # ele só delega ao journalized.visible?, que responde sobre a tarefa. Quem
    # aplica :view_private_notes é o método abaixo.
    def journals(issue)
      issue.visible_journals_with_index(User.current)
           .select { |j| j.notes.present? }
           .map do |j|
        {
          'id' => j.id,
          'user' => named(j.user),
          'notes' => j.notes,
          'private' => j.private_notes,
          'created_on' => j.created_on&.utc&.iso8601
        }
      end
    end

    def url_for(path)
      base = Config.base_url
      base.present? ? "#{base}#{path}" : path
    end
  end
end
