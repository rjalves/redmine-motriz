require_relative '../test_helper'

class McpDiscoveryControllerTest < Redmine::ControllerTest
  tests McpDiscoveryController

  def setup
    User.current = nil
    Setting.rest_api_enabled = '1'
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'dynamic_registration' => '1'}
  end

  def json = JSON.parse(@response.body)

  # Descoberta é pública por definição: o cliente ainda não tem token quando
  # chega aqui — é justamente o 401 que o manda para cá.
  def test_protected_resource_e_publico
    get :protected_resource, params: {format: 'json'}
    assert_response :success
    assert_equal RedmineMcpServer::Config.resource_uri, json['resource']
    assert json['authorization_servers'].is_a?(Array)
    assert_equal ['header'], json['bearer_methods_supported']
    assert_includes json['scopes_supported'], 'view_issues'
  end

  def test_authorization_server_aponta_para_os_endpoints_reais_do_doorkeeper
    get :authorization_server, params: {format: 'json'}
    assert_response :success
    assert_match(%r{/oauth/authorize\z}, json['authorization_endpoint'])
    assert_match(%r{/oauth/token\z}, json['token_endpoint'])
    assert_equal ['code'], json['response_types_supported']
    assert_includes json['grant_types_supported'], 'authorization_code'
  end

  # "plain" existe no PKCE mas não protege contra intercepção do code.
  def test_so_anuncia_pkce_s256
    get :authorization_server, params: {format: 'json'}
    assert_equal ['S256'], json['code_challenge_methods_supported']
  end

  def test_registration_endpoint_some_quando_o_registro_dinamico_esta_desligado
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'dynamic_registration' => '0'}
    get :authorization_server, params: {format: 'json'}
    refute json.key?('registration_endpoint')
  end

  def test_registration_endpoint_aparece_quando_ligado
    get :authorization_server, params: {format: 'json'}
    assert_match(%r{/mcp/register\z}, json['registration_endpoint'])
  end

  def test_os_escopos_anunciados_sao_permissoes_reais_do_redmine
    # Se um escopo não for permissão conhecida, o Doorkeeper recusa o token por
    # enforce_configured_scopes (30-redmine.rb:56) e o login falha em produção.
    conhecidas = Redmine::AccessControl.permissions.map { |p| p.name.to_s }
    RedmineMcpServer::Config::SCOPES.each do |scope|
      assert_includes conhecidas, scope, "escopo '#{scope}' não é permissão do Redmine"
    end
  end
end
