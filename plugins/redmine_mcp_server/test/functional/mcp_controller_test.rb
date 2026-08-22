require_relative '../test_helper'

class McpControllerTest < Redmine::ControllerTest
  tests McpController

  V = RedmineMcpServer::Config::PROTOCOL_VERSION

  def setup
    User.current = nil
    Setting.rest_api_enabled = '1'
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'rate_limit' => '60'}
    @user = User.find(2)
    @user.pref[:mcp_enabled] = '1'
    @user.pref.save
    RedmineMcpServer::Throttle.reset!(@user.id)
  end

  def teardown
    User.current = nil
  end

  # Sessão NÃO autentica aqui, e isso não é limitação do teste: find_current_user
  # só olha a sessão quando `!api_request?` (application_controller.rb:114-129),
  # e a rota do MCP fixa format=json justamente para pular o CSRF. Em produção
  # quem autentica é o Bearer do Doorkeeper; no teste, a chave de API percorre o
  # mesmo caminho (:131-133) sem precisar montar um token OAuth.
  def as(user)
    @request.headers['X-Redmine-API-Key'] = user.api_key if user
  end

  def rpc(method, params = {}, id: 1, version: V, headers: {}, body_override: nil)
    meta = {
      RedmineMcpServer::Envelope::META_VERSION => version,
      RedmineMcpServer::Envelope::META_CAPABILITIES => {}
    }
    body = body_override || {
      'jsonrpc' => '2.0', 'id' => id, 'method' => method,
      'params' => params.merge('_meta' => meta)
    }
    default = {'MCP-Protocol-Version' => version, 'Mcp-Method' => method}
    default['Mcp-Name'] = params['name'] if method == 'tools/call' && params['name']
    default.merge(headers).each { |k, v| @request.headers[k] = v }
    @request.headers['CONTENT_TYPE'] = 'application/json'
    post :handle, body: body.to_json, params: {format: 'json'}
  end

  def json = JSON.parse(@response.body)

  # jsmith tem mais de um papel, e Role#remove_permission! não limpa a
  # memoização de @allowed_permissions (app/models/role.rb:140-146) — daí mexer
  # em todos e recarregar.
  def revoke(*permissions)
    Role.all.each { |r| r.remove_permission!(*permissions) }
    @user = User.find(@user.id)
  end

  # O Redmine usa :null_store em teste (config/environments/test.rb:36), onde
  # increment nunca persiste e o limitador viraria no-op. Troca por um store de
  # memória só durante o bloco.
  def with_real_cache
    original = Rails.cache
    Rails.instance_variable_set(:@cache, ActiveSupport::Cache::MemoryStore.new)
    yield
  ensure
    Rails.instance_variable_set(:@cache, original)
  end

  # ----------------------------------------------------------------- acesso

  def test_sem_token_responde_401_com_www_authenticate_da_rfc_9728
    rpc('tools/list')
    assert_response :unauthorized
    challenge = @response.headers['WWW-Authenticate']
    assert_match(/\ABearer /, challenge)
    assert_match(%r{resource_metadata="[^"]*/\.well-known/oauth-protected-resource"}, challenge)
    assert_match(/scope="/, challenge)
  end

  def test_get_e_delete_respondem_405
    as(@user)
    [:get, :delete].each do |verb|
      send(verb, :handle, params: {format: 'json'})
      assert_response :method_not_allowed, "#{verb} deveria ser 405"
      assert_equal 'POST', @response.headers['Allow']
    end
  end

  def test_origin_desconhecida_e_403
    as(@user)
    rpc('tools/list', headers: {'Origin' => 'https://evil.example.com'})
    assert_response :forbidden
  end

  def test_origin_do_proprio_host_passa
    as(@user)
    rpc('tools/list', headers: {'Origin' => "#{@request.protocol}#{@request.host_with_port}"})
    assert_response :success
  end

  def test_usuario_que_nao_habilitou_recebe_403
    @user.pref[:mcp_enabled] = '0'
    @user.pref.save
    as(@user)
    rpc('tools/list')
    assert_response :forbidden
  end

  def test_plugin_desligado_responde_503
    Setting.plugin_redmine_mcp_server = {'enabled' => '0'}
    as(@user)
    rpc('tools/list')
    assert_response :service_unavailable
  end

  def test_api_rest_desligada_responde_503
    Setting.rest_api_enabled = '0'
    as(@user)
    rpc('tools/list')
    assert_response :service_unavailable
  end

  # ---------------------------------------------------------------- envelope

  def test_header_divergente_do_corpo_e_400_com_32020
    as(@user)
    rpc('tools/list', headers: {'Mcp-Method' => 'tools/call'})
    assert_response :bad_request
    assert_equal(-32020, json['error']['code'])
  end

  def test_versao_desconhecida_e_400_com_32022
    as(@user)
    rpc('tools/list', version: '1999-01-01')
    assert_response :bad_request
    assert_equal(-32022, json['error']['code'])
    assert_includes json['error']['data']['supported'], V
  end

  def test_json_invalido_e_erro_de_parse
    as(@user)
    @request.headers['CONTENT_TYPE'] = 'application/json'
    post :handle, body: '{nao é json', params: {format: 'json'}
    assert_response :bad_request
    assert_equal(-32700, json['error']['code'])
  end

  def test_metodo_desconhecido_e_404_com_32601
    as(@user)
    rpc('coisa/inexistente')
    assert_response :not_found
    assert_equal(-32601, json['error']['code'])
  end

  def test_notificacao_responde_202_sem_corpo
    as(@user)
    body = {'jsonrpc' => '2.0', 'method' => 'ping',
            'params' => {'_meta' => {RedmineMcpServer::Envelope::META_VERSION => V,
                                     RedmineMcpServer::Envelope::META_CAPABILITIES => {}}}}
    rpc('ping', body_override: body)
    assert_response :accepted
    assert @response.body.blank?
  end

  # ------------------------------------------------------------------ tools

  def test_tools_list_devolve_result_type_complete
    as(@user)
    rpc('tools/list')
    assert_response :success
    assert_equal 'complete', json['result']['resultType']
    assert json['result']['tools'].any?
  end

  def test_tools_list_esconde_escrita_de_quem_nao_pode
    revoke(:add_issues, :edit_issues, :add_issue_notes, :log_time)
    as(@user)
    rpc('tools/list')
    nomes = json['result']['tools'].map { |t| t['name'] }
    assert_includes nomes, 'list_issues'
    refute_includes nomes, 'create_issue'
  end

  def test_tools_call_executa_e_devolve_structured_content
    as(@user)
    rpc('tools/call', {'name' => 'list_projects', 'arguments' => {'limit' => 5}})
    assert_response :success
    assert_equal false, json['result']['isError']
    assert json['result']['structuredContent']['projects'].is_a?(Array)
  end

  def test_tools_call_de_ferramenta_sem_permissao_e_ferramenta_desconhecida
    revoke(:add_issues)
    as(@user)
    rpc('tools/call', {'name' => 'create_issue', 'arguments' => {}})
    assert_response :bad_request
    assert_equal(-32602, json['error']['code'])
    assert_match(/Unknown tool/, json['error']['message'])
  end

  # Erro de execução não é erro de protocolo: vai como isError, para o modelo
  # ler a mensagem e se corrigir.
  def test_erro_de_execucao_vem_como_is_error_e_nao_como_erro_jsonrpc
    as(@user)
    rpc('tools/call', {'name' => 'get_issue', 'arguments' => {'id' => 999_999}})
    assert_response :success
    assert_equal true, json['result']['isError']
    assert_match(/not found or not visible/, json['result']['content'][0]['text'])
  end

  def test_limite_de_taxa_devolve_is_error
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'rate_limit' => '2'}
    as(@user)
    with_real_cache do
      3.times { rpc('tools/call', {'name' => 'list_projects', 'arguments' => {}}) }
    end
    assert_response :success
    assert_equal true, json['result']['isError']
    assert_match(/Rate limit/, json['result']['content'][0]['text'])
  end

  # Com cache nulo o limitador não tem como contar. Deixar passar é a escolha
  # certa — derrubar o servidor por causa do cache seria pior —, mas tem que
  # ficar registrado no log, senão parece protegido e não está.
  def test_cache_nulo_desliga_o_limite_e_avisa
    refute RedmineMcpServer::Throttle.available?
    permitido, = RedmineMcpServer::Throttle.hit(@user.id, 1)
    assert permitido
  end

  def test_chamada_e_registrada_na_auditoria_sem_o_valor_dos_argumentos
    as(@user)
    assert_difference('McpToolCall.count', 1) do
      rpc('tools/call', {'name' => 'list_projects', 'arguments' => {'query' => 'segredo'}})
    end
    call = McpToolCall.last
    assert_equal 'list_projects', call.tool_name
    assert_equal 'query', call.argument_keys
    assert call.ok?
    refute_match(/segredo/, call.attributes.values.map(&:to_s).join(' '),
                 'o valor do argumento não pode ser persistido')
  end
end
