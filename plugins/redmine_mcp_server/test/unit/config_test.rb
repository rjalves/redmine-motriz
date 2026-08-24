require_relative '../test_helper'

class RedmineMcpServer::ConfigTest < ActiveSupport::TestCase
  C = RedmineMcpServer::Config

  # O Redmine guarda as settings de um plugin como UM hash serializado. Se o
  # plugin ganha uma chave nova depois que alguém já salvou a tela de
  # configuração, essa chave simplesmente NÃO existe no hash gravado — o
  # `default:` do init.rb não é mesclado retroativamente. Sem tratar isso, todo
  # upgrade do plugin nasce com a funcionalidade nova desligada e sem aviso.
  def test_chave_ausente_no_banco_cai_no_default_declarado
    Setting.plugin_redmine_mcp_server = {'enabled' => '1'} # sem allowed_origins
    assert_equal ['https://claude.ai'], C.allowed_origins
    assert_equal 60, C.rate_limit
  end

  # Mas se o admin esvaziou o campo de propósito, isso é uma escolha e tem que
  # ser respeitada — não pode ressuscitar o default.
  def test_campo_esvaziado_pelo_admin_continua_vazio
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'allowed_origins' => ''}
    assert_empty C.allowed_origins
  end

  def test_valor_gravado_vence_o_default
    Setting.plugin_redmine_mcp_server = {'allowed_origins' => 'https://cursor.sh'}
    assert_equal ['https://cursor.sh'], C.allowed_origins
  end

  def test_varias_origens_por_linha_ou_virgula
    Setting.plugin_redmine_mcp_server = {
      'allowed_origins' => "https://claude.ai\n https://cursor.sh , https://x.dev"
    }
    assert_equal %w[https://claude.ai https://cursor.sh https://x.dev], C.allowed_origins
  end

  def test_available_exige_plugin_ligado_e_api_rest_ligada
    Setting.rest_api_enabled = '1'
    Setting.plugin_redmine_mcp_server = {'enabled' => '1'}
    assert C.available?

    Setting.plugin_redmine_mcp_server = {'enabled' => '0'}
    refute C.available?

    Setting.plugin_redmine_mcp_server = {'enabled' => '1'}
    Setting.rest_api_enabled = '0'
    refute C.available?
  end

  def test_resource_uri_nao_tem_barra_final
    refute C.resource_uri.end_with?('/')
    assert C.resource_uri.end_with?('/mcp')
  end
end
