require_relative '../test_helper'

# A tela de configuração do plugin recebe do SettingsController o hash CRU do
# banco, sem os defaults do init.rb mesclados. Renderizar esse hash direto cria
# um alçapão silencioso: toda chave que o plugin ganhar depois da última
# gravação aparece vazia na tela, e o primeiro Save persiste "" por cima do
# default — que o Config trata, corretamente, como "o admin limpou de propósito".
#
# Aconteceu de verdade: allowed_origins virou "" em produção e o CORS voltou a
# recusar o claude.ai depois de já estar funcionando.
class McpSettingsViewTest < Redmine::ControllerTest
  tests SettingsController

  def setup
    @request.session[:user_id] = 1
    Setting.rest_api_enabled = '1'
  end

  def test_chave_ausente_no_banco_renderiza_o_default
    Setting.plugin_redmine_mcp_server = {'enabled' => '1'} # sem allowed_origins
    get :plugin, params: {id: 'redmine_mcp_server'}
    assert_response :success
    assert_select 'textarea#settings_allowed_origins', text: /claude\.ai/
    assert_select 'input#settings_rate_limit[value=?]', '60'
  end

  # O contrário também tem que valer: o que o admin gravou é o que aparece.
  def test_valor_gravado_aparece_na_tela
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'allowed_origins' => 'https://cursor.sh'}
    get :plugin, params: {id: 'redmine_mcp_server'}
    assert_select 'textarea#settings_allowed_origins', text: /cursor\.sh/
  end

  # E o campo esvaziado de propósito continua vazio — é uma escolha legítima
  # (endpoint só servidor-a-servidor, sem navegador nenhum).
  def test_campo_esvaziado_continua_vazio
    Setting.plugin_redmine_mcp_server = {'enabled' => '1', 'allowed_origins' => ''}
    get :plugin, params: {id: 'redmine_mcp_server'}
    assert_select 'textarea#settings_allowed_origins', text: ''
  end

  # O teste que fecha o ciclo: abrir a tela e salvar sem tocar em nada não pode
  # apagar configuração.
  def test_salvar_sem_editar_preserva_o_default
    Setting.plugin_redmine_mcp_server = {'enabled' => '1'}
    get :plugin, params: {id: 'redmine_mcp_server'}
    campo = css_select('textarea#settings_allowed_origins').first.text

    post :plugin, params: {
      id: 'redmine_mcp_server',
      settings: {'enabled' => '1', 'allowed_origins' => campo, 'rate_limit' => '60'}
    }
    assert_equal ['https://claude.ai'], RedmineMcpServer::Config.allowed_origins
  end
end
