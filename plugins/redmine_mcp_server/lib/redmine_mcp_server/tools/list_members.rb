# frozen_string_literal: true

module RedmineMcpServer
  module Tools
    # Quem participa de um projeto, e com que papel.
    #
    # Existe porque sem ela o assistente não tem como transformar "atribuir ao
    # Alberto" num `assigned_to_id`: create_issue e update_issue pedem o id
    # numérico, e nenhuma outra ferramenta revela ids de pessoas. O escopo
    # `view_members` já era pedido no consentimento OAuth desde o começo, sem
    # que nada o usasse.
    #
    # Espelha MembersController#index: mesmo escopo (`@project.memberships`),
    # mesma permissão e os mesmos campos do index.api.rsb — id, nome e papéis.
    # Login e e-mail ficam de fora porque a API do core também os deixa.
    class ListMembers < Base
      # Permissão pública no core (lib/redmine/preparation.rb:45): quem enxerga
      # o projeto enxerga quem participa dele. Por ser pública, ela entra nos
      # default_scopes do Doorkeeper e está sempre presente no token.
      def self.permission = :view_members

      def self.description
        'List the people and groups who are members of a project, with their roles. ' \
        'Use the returned id as assigned_to_id when creating or updating an issue.'
      end

      def self.input_schema
        {
          'type' => 'object',
          'properties' => {
            'project_id' => {'type' => 'string',
                             'description' => 'Project identifier or numeric id'},
            'limit' => {'type' => 'integer', 'description' => '1-100, defaults to 25'},
            'offset' => {'type' => 'integer'}
          },
          'required' => ['project_id'],
          'additionalProperties' => false
        }
      end

      def call(arguments)
        project = find_project!(arguments['project_id'])
        require_permission!(:view_members, project)

        offset, limit = paginate(arguments)
        scope = project.memberships.includes(:principal, :roles).order(:id)
        total = scope.count
        members = scope.offset(offset).limit(limit).to_a

        structured = {
          'total_count' => total, 'offset' => offset, 'limit' => limit,
          'project' => {'id' => project.id, 'identifier' => project.identifier},
          'members' => members.map { |m| present(m) }
        }
        result(as_text(members), structured)
      end

      private

      def present(member)
        principal = member.principal
        {
          'id' => principal&.id,
          'name' => principal&.name,
          # Grupo também pode ser membro, e não serve como assigned_to a menos
          # que o Redmine esteja configurado para permitir. Dizer o tipo evita
          # que o modelo tente atribuir para um grupo sem saber.
          'type' => principal.is_a?(Group) ? 'group' : 'user',
          'roles' => member.member_roles.filter_map { |mr| mr.role&.name }.uniq
        }.compact
      end

      def as_text(members)
        return 'This project has no members.' if members.empty?

        members.map do |m|
          papeis = m.member_roles.filter_map { |mr| mr.role&.name }.uniq.join(', ')
          "#{m.principal&.id} — #{m.principal&.name} (#{papeis.presence || 'no role'})"
        end.join("\n")
      end
    end
  end
end
