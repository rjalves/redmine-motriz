# frozen_string_literal: true

module RedmineMcpServer
  # Catálogo de ferramentas.
  #
  # A especificação permite explicitamente que a lista varie conforme a
  # autorização apresentada: "MAY vary by the authorization presented on the
  # request — since credentials are per-request input, not connection state".
  # É por isso que quem só tem leitura nem enxerga create_issue.
  module Registry
    # Ordem fixa: a especificação pede ordenação determinística, porque os
    # clientes cacheiam a lista e ela entra no prompt do modelo.
    TOOLS = [
      Tools::Search,
      Tools::ListProjects,
      Tools::GetProject,
      Tools::ListMembers,
      Tools::ListIssues,
      Tools::GetIssue,
      Tools::ListTimeEntries,
      Tools::GetWikiPage,
      Tools::ListEnumerations,
      Tools::CreateIssue,
      Tools::UpdateIssue,
      Tools::AddIssueNote,
      Tools::LogTime
    ].freeze

    module_function

    def all
      TOOLS
    end

    def available_to(user)
      TOOLS.select { |t| t.available_to?(user) }
    end

    def definitions_for(user)
      available_to(user).map(&:definition)
    end

    def find(name)
      TOOLS.find { |t| t.tool_name == name.to_s }
    end

    # Resolve o nome para uma ferramenta que este usuário pode usar.
    # Devolve nil se não existe OU se ele não pode — o chamador trata os dois
    # como "ferramenta desconhecida", para não revelar o catálogo alheio.
    def resolve(name, user)
      tool = find(name)
      return nil unless tool&.available_to?(user)

      tool
    end
  end
end
