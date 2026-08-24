Redmine::Plugin.register :redmine_mcp_server do
  name        'Redmine MCP Server'
  author      'Roberto Alves'
  description 'Servidor MCP embutido: assistentes de IA operam o Redmine dentro das permissões de cada usuário'
  version     '0.1.0'
  url         'https://github.com/rjalves/redmine-motriz'
  requires_redmine version_or_higher: '7.0.0'

  settings default: {
             'enabled'              => '0',
             'dynamic_registration' => '0',
             'rate_limit'           => '60',
             'allowed_origins'      => 'https://claude.ai',
             'retention_days'       => '90'
           },
           partial: 'settings/redmine_mcp_server_settings'

  menu :admin_menu, :mcp_tool_calls,
       {controller: 'mcp_tool_calls', action: 'index'},
       caption: :label_mcp_tool_calls,
       html: {class: 'icon icon-summary'},
       if: proc { RedmineMcpServer::Config.enabled? }
end

# Referenciar as constantes basta: o Zeitwerk carrega lib/ do plugin e o
# `inherited` de Redmine::Hook::Listener registra o listener. Nada de require —
# o lib/ é autoloadado e requerer à mão duplicaria a constante a cada reload.
RedmineMcpServer::Hooks
