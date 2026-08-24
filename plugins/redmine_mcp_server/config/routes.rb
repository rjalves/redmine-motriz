# Rotas do servidor MCP.
#
# `defaults: {format: 'json'}` no endpoint não é cosmético: api_request? do core
# é `%w(xml json).include? params[:format]`, e é isso — e só isso — que faz
# verify_authenticity_token pular a checagem de CSRF
# (application_controller.rb:43-47). Sem o format fixo, todo POST morre em 422.

# O endpoint em si. Um único path, POST. A revisão 2026-07-28 não tem stream por
# GET nem encerramento por DELETE; as duas rotas existem para responder 405 com
# um corpo JSON-RPC decente, em vez do 404 cru do Rails.
match 'mcp', to: 'mcp#handle', via: [:post], defaults: {format: 'json'}, as: 'mcp_endpoint'
match 'mcp', to: 'mcp#handle', via: [:get, :delete, :put, :patch], defaults: {format: 'json'}

# Preflight CORS. Sem esta rota o navegador recebe 404 no OPTIONS e desiste
# antes de emitir o POST — o cliente só reporta uma falha genérica.
# `as: nil` porque o Rails autonomearia estas rotas a partir do caminho, e os
# nomes 'mcp' e 'mcp_register' já pertencem às rotas de POST acima.
match 'mcp', to: 'mcp#preflight', via: [:options], defaults: {format: 'json'}, as: nil
match 'mcp/register', to: 'mcp_registration#preflight', via: [:options],
      defaults: {format: 'json'}, as: nil

# Registro dinâmico de cliente (RFC 7591).
post 'mcp/register', to: 'mcp_registration#create', defaults: {format: 'json'}, as: 'mcp_register'

# Descoberta. A RFC 9728 manda o cliente tentar primeiro a forma com o path do
# recurso inserido depois do .well-known, e cair para a forma simples; servimos
# as duas.
get '.well-known/oauth-protected-resource/mcp',
    to: 'mcp_discovery#protected_resource', defaults: {format: 'json'}
get '.well-known/oauth-protected-resource',
    to: 'mcp_discovery#protected_resource', defaults: {format: 'json'}, as: 'mcp_protected_resource'
get '.well-known/oauth-authorization-server',
    to: 'mcp_discovery#authorization_server', defaults: {format: 'json'}, as: 'mcp_authorization_server'

# Habilitação pela pessoa, em Minha conta.
post 'mcp/access', to: 'mcp_access#update', as: 'mcp_access'
post 'mcp/revoke_tokens', to: 'mcp_access#revoke_tokens', as: 'mcp_revoke_tokens'

# Auditoria (admin).
get 'admin/mcp_tool_calls', to: 'mcp_tool_calls#index', as: 'mcp_tool_calls'
