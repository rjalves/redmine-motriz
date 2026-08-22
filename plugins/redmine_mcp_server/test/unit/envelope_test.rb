require_relative '../test_helper'

class RedmineMcpServer::EnvelopeTest < ActiveSupport::TestCase
  V = RedmineMcpServer::Config::PROTOCOL_VERSION
  E = RedmineMcpServer::Envelope

  # Um duplo mínimo: o Envelope só lê request.headers.
  class FakeRequest
    def initialize(headers) = @headers = headers
    def headers = @headers
  end

  def body(method: 'tools/list', id: 1, params: nil, version: V)
    meta = {E::META_VERSION => version, E::META_CAPABILITIES => {}}
    {'jsonrpc' => '2.0', 'id' => id, 'method' => method,
     'params' => (params || {}).merge('_meta' => meta)}
  end

  def headers(extra = {})
    {'MCP-Protocol-Version' => V, 'Mcp-Method' => 'tools/list'}.merge(extra)
  end

  def parse(hdrs, bdy)
    E.parse(FakeRequest.new(hdrs), bdy)
  end

  def test_envelope_valido_expoe_metodo_id_e_versao
    env = parse(headers, body)
    assert_equal 'tools/list', env.method_name
    assert_equal 1, env.id
    assert_equal V, env.protocol_version
    refute env.notification?
  end

  def test_notificacao_e_requisicao_sem_id
    bdy = body(id: nil).except('id')
    env = parse(headers, bdy)
    assert env.notification?
  end

  def test_mcp_method_divergente_do_corpo_e_header_mismatch
    erro = assert_raises(E::Error) { parse(headers('Mcp-Method' => 'tools/call'), body) }
    assert_equal E::HEADER_MISMATCH, erro.code
    assert_equal 400, erro.http_status
  end

  def test_mcp_method_ausente_e_header_mismatch
    erro = assert_raises(E::Error) { parse(headers.except('Mcp-Method'), body) }
    assert_equal E::HEADER_MISMATCH, erro.code
  end

  def test_mcp_name_precisa_casar_em_tools_call
    bdy = body(method: 'tools/call', params: {'name' => 'get_issue'})
    hdrs = headers('Mcp-Method' => 'tools/call', 'Mcp-Name' => 'get_issue')
    assert parse(hdrs, bdy)

    erro = assert_raises(E::Error) do
      parse(headers('Mcp-Method' => 'tools/call', 'Mcp-Name' => 'outra'), bdy)
    end
    assert_equal E::HEADER_MISMATCH, erro.code
  end

  def test_mcp_name_aceita_o_sentinela_base64
    nome = 'acentuação'
    codificado = "=?base64?#{Base64.strict_encode64(nome)}?="
    bdy = body(method: 'tools/call', params: {'name' => nome})
    hdrs = headers('Mcp-Method' => 'tools/call', 'Mcp-Name' => codificado)
    assert parse(hdrs, bdy)
  end

  def test_decode_header_devolve_o_valor_cru_quando_nao_e_sentinela
    assert_equal 'get_issue', E.decode_header('get_issue')
    assert_nil E.decode_header(nil)
  end

  def test_versao_de_protocolo_desconhecida_e_recusada_listando_as_suportadas
    hdrs = headers('MCP-Protocol-Version' => '1999-01-01')
    erro = assert_raises(E::Error) { parse(hdrs, body(version: '1999-01-01')) }
    assert_equal E::UNSUPPORTED_PROTOCOL_VERSION, erro.code
    assert_includes erro.data['supported'], V
  end

  def test_versao_no_header_divergente_do_meta_e_header_mismatch
    hdrs = headers('MCP-Protocol-Version' => V)
    erro = assert_raises(E::Error) { parse(hdrs, body(version: '2025-06-18')) }
    assert_equal E::HEADER_MISMATCH, erro.code
  end

  def test_meta_obrigatorio_na_era_moderna
    bdy = body
    bdy['params']['_meta'].delete(E::META_CAPABILITIES)
    erro = assert_raises(E::Error) { parse(headers, bdy) }
    assert_equal E::INVALID_PARAMS, erro.code
  end

  # Cliente antigo não manda _meta nem os cabeçalhos espelhados — eles só
  # passaram a existir em 2026-07-28. Exigi-los o barraria sem motivo.
  def test_cliente_de_era_antiga_nao_precisa_de_meta_nem_headers_espelhados
    bdy = {'jsonrpc' => '2.0', 'id' => 7, 'method' => 'tools/list'}
    env = parse({'MCP-Protocol-Version' => '2025-06-18'}, bdy)
    assert_equal '2025-06-18', env.protocol_version
    refute env.modern?
  end

  def test_sem_header_de_versao_assume_a_era_mais_antiga
    bdy = {'jsonrpc' => '2.0', 'id' => 8, 'method' => 'ping'}
    assert_equal '2025-03-26', parse({}, bdy).protocol_version
  end

  def test_initialize_nao_exige_meta
    bdy = {'jsonrpc' => '2.0', 'id' => 9, 'method' => 'initialize', 'params' => {}}
    assert parse(headers('Mcp-Method' => 'initialize'), bdy)
  end

  def test_corpo_sem_jsonrpc_2_e_invalid_request
    erro = assert_raises(E::Error) { parse(headers, body.merge('jsonrpc' => '1.0')) }
    assert_equal E::INVALID_REQUEST, erro.code
  end
end
