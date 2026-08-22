# frozen_string_literal: true

module RedmineMcpServer
  # Único ponto de leitura de configuração do plugin.
  module Config
    # A revisão da especificação que este servidor implementa.
    PROTOCOL_VERSION = '2026-07-28'

    # Revisões antigas que ainda aceitamos no cabeçalho, para clientes que não
    # migraram. O comportamento do servidor é o mesmo em todas: POST, sem sessão.
    SUPPORTED_PROTOCOL_VERSIONS = [
      PROTOCOL_VERSION, '2025-11-25', '2025-06-18', '2025-03-26'
    ].freeze

    # Os escopos OAuth que o servidor anuncia. São nomes de permissão do Redmine:
    # `optional_scopes` do Doorkeeper é justamente a lista de permissões
    # (config/initializers/30-redmine.rb:52), e Role#allowed_to? intersecta o
    # escopo do token com as permissões do papel. Nada aqui concede poder — só
    # limita o teto do que o token pode pedir.
    SCOPES = %w[
      view_project search_project view_members
      view_issues add_issues edit_issues add_issue_notes
      view_time_entries log_time
      view_wiki_pages
    ].freeze

    module_function

    def settings
      Setting.plugin_redmine_mcp_server || {}
    end

    def enabled?
      settings['enabled'].to_s == '1'
    end

    def dynamic_registration_enabled?
      settings['dynamic_registration'].to_s == '1'
    end

    def rate_limit
      limit = settings['rate_limit'].to_i
      limit.positive? ? limit : 60
    end

    # Sem isto, nenhum Bearer token funciona: find_current_user só chega ao ramo
    # do Doorkeeper se Setting.rest_api_enabled? (application_controller.rb:130).
    def rest_api_enabled?
      Setting.rest_api_enabled?
    end

    def available?
      enabled? && rest_api_enabled?
    end

    # A URI canônica do recurso, no sentido da RFC 8707 — sem barra final.
    def resource_uri
      "#{base_url}/mcp"
    end

    def base_url
      Setting.protocol && Setting.host_name ? "#{Setting.protocol}://#{Setting.host_name}" : ''
    end

    def enabled_for?(user)
      return false unless user&.logged?

      user.pref[:mcp_enabled].to_s == '1'
    end
  end
end
