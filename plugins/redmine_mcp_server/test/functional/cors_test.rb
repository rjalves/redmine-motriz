require_relative '../test_helper'

# CORS não é enfeite aqui: o conector do Claude sonda o endpoint a partir do
# NAVEGADOR, não só dos servidores dele. Sem preflight e sem os cabeçalhos, o
# navegador nem chega a emitir o POST, e o cliente só reporta um genérico
# "credential validation failed".
class McpCorsTest < Redmine::ControllerTest
  tests McpController

  V = RedmineMcpServer::Config::PROTOCOL_VERSION
  ORIGEM = 'https://claude.ai'.freeze

  def setup
    User.current = nil
    Setting.rest_api_enabled = '1'
    Setting.plugin_redmine_mcp_server = {
      'enabled' => '1', 'rate_limit' => '60', 'allowed_origins' => ORIGEM
    }
    @user = User.find(2)
    @user.pref[:mcp_enabled] = '1'
    @user.pref.save
  end

  def teardown
    User.current = nil
  end

  def preflight(origin: ORIGEM, headers: 'authorization,content-type,mcp-protocol-version')
    @request.headers['Origin'] = origin
    @request.headers['Access-Control-Request-Method'] = 'POST'
    @request.headers['Access-Control-Request-Headers'] = headers
    process :preflight, method: 'OPTIONS', params: {format: 'json'}
  end

  def test_preflight_responde_204_e_nao_404
    preflight
    assert_response :no_content
  end

  def test_preflight_libera_a_origem_configurada
    preflight
    assert_equal ORIGEM, @response.headers['Access-Control-Allow-Origin']
    assert_includes @response.headers['Access-Control-Allow-Methods'], 'POST'
  end

  # Os cabeçalhos espelhados da revisão 2026-07-28 (Mcp-Method, Mcp-Name e os
  # Mcp-Param-* dinâmicos) precisam passar. Como Mcp-Param-* é aberto, ecoamos
  # o que o navegador pediu em vez de manter uma lista que envelhece.
  def test_preflight_libera_os_cabecalhos_do_protocolo
    preflight(headers: 'authorization,content-type,mcp-protocol-version,mcp-method,mcp-name,mcp-param-region')
    permitidos = @response.headers['Access-Control-Allow-Headers'].to_s.downcase
    %w[authorization content-type mcp-protocol-version mcp-method mcp-name mcp-param-region].each do |h|
      assert_includes permitidos, h, "cabeçalho #{h} não liberado no preflight"
    end
  end

  def test_preflight_de_origem_desconhecida_e_recusado
    preflight(origin: 'https://evil.example.com')
    assert_response :forbidden
    assert_nil @response.headers['Access-Control-Allow-Origin']
  end

  def test_resposta_normal_carrega_o_allow_origin
    @request.headers['X-Redmine-API-Key'] = @user.api_key
    @request.headers['Origin'] = ORIGEM
    @request.headers['MCP-Protocol-Version'] = V
    @request.headers['Mcp-Method'] = 'tools/list'
    @request.headers['CONTENT_TYPE'] = 'application/json'
    post :handle, params: {format: 'json'}, body: {
      'jsonrpc' => '2.0', 'id' => 1, 'method' => 'tools/list',
      'params' => {'_meta' => {RedmineMcpServer::Envelope::META_VERSION => V,
                               RedmineMcpServer::Envelope::META_CAPABILITIES => {}}}
    }.to_json
    assert_response :success
    assert_equal ORIGEM, @response.headers['Access-Control-Allow-Origin']
  end

  # Sem expor WWW-Authenticate, um cliente de navegador não consegue LER o
  # desafio do 401 e nunca descobre onde autenticar — o fluxo inteiro trava.
  def test_401_expoe_o_www_authenticate_para_o_navegador
    @request.headers['Origin'] = ORIGEM
    @request.headers['CONTENT_TYPE'] = 'application/json'
    post :handle, params: {format: 'json'}, body: '{}'
    assert_response :unauthorized
    assert_equal ORIGEM, @response.headers['Access-Control-Allow-Origin']
    expostos = @response.headers['Access-Control-Expose-Headers'].to_s.downcase
    assert_includes expostos, 'www-authenticate'
  end

  def test_a_propria_origem_do_redmine_continua_liberada
    Setting.plugin_redmine_mcp_server =
      Setting.plugin_redmine_mcp_server.merge('allowed_origins' => '')
    preflight(origin: "#{@request.protocol}#{@request.host_with_port}")
    assert_response :no_content
  end

  def test_varias_origens_podem_ser_configuradas
    Setting.plugin_redmine_mcp_server = Setting.plugin_redmine_mcp_server.merge(
      'allowed_origins' => "https://claude.ai\nhttps://cursor.sh")
    preflight(origin: 'https://cursor.sh')
    assert_response :no_content
    assert_equal 'https://cursor.sh', @response.headers['Access-Control-Allow-Origin']
  end
end
