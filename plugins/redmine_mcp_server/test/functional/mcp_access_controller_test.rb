require_relative '../test_helper'

class McpAccessControllerTest < Redmine::ControllerTest
  tests McpAccessController

  def setup
    User.current = nil
    Setting.rest_api_enabled = '1'
    Setting.plugin_redmine_mcp_server = {'enabled' => '1'}
    @user = User.find(2)
    @user.pref[:mcp_enabled] = nil
    @user.pref.save
    @request.session[:user_id] = @user.id
  end

  def teardown
    User.current = nil
  end

  def test_pagina_exige_login
    @request.session[:user_id] = nil
    get :show
    assert_response :redirect
  end

  def test_pagina_some_com_o_plugin_desligado
    Setting.plugin_redmine_mcp_server = {'enabled' => '0'}
    get :show
    assert_response :not_found
  end

  def test_desabilitado_mostra_botao_de_habilitar
    get :show
    assert_response :success
    assert_select 'form[action=?]', '/mcp/access?enabled=1'
    assert_select '#mcp-url', 0
  end

  def test_habilitar_persiste_a_preferencia_e_volta_para_a_pagina
    post :update, params: {enabled: '1'}
    assert_redirected_to '/mcp/access'
    assert_equal '1', User.find(@user.id).pref[:mcp_enabled]
  end

  def test_habilitado_mostra_a_url_de_conexao
    @user.pref[:mcp_enabled] = '1'
    @user.pref.save
    get :show
    assert_response :success
    assert_select '#mcp-url[value=?]', RedmineMcpServer::Config.resource_uri
  end

  def test_desabilitar_persiste
    @user.pref[:mcp_enabled] = '1'
    @user.pref.save
    post :update, params: {enabled: '0'}
    assert_equal '0', User.find(@user.id).pref[:mcp_enabled]
  end

  # Habilitar é mudança de estado: não pode acontecer por GET, senão um <img>
  # numa página qualquer liga o acesso por IA de quem visitar. Quem garante isso
  # é a rota — em teste de controller `get :update` fabrica a requisição sem
  # passar pelo roteador, então a asserção tem que ser sobre o roteamento.
  def test_get_em_mcp_access_e_a_pagina_e_nao_a_mudanca_de_estado
    assert_recognizes({controller: 'mcp_access', action: 'show'},
                      {path: '/mcp/access', method: :get})
    assert_recognizes({controller: 'mcp_access', action: 'update'},
                      {path: '/mcp/access', method: :post})
  end
end

# O bloco que o hook :view_my_account injeta é renderizado DENTRO do
# `labelled_form_for` de Minha conta — tanto no core (my/account.html.erb:53)
# quanto no motriz_2 (user_settings/_preferences.html.erb:15). <form> dentro de
# <form> é inválido: o parser HTML descarta o interno e o botão passa a submeter
# o formulário externo, sem nunca chegar ao McpAccessController.
#
# Foi exatamente esse o bug que deixou o conector do Claude tomando 403 em toda
# chamada — ninguém conseguia habilitar o acesso, porque o botão era inerte.
#
# A verificação precisa ser sobre o TEXTO renderizado. assert_select não serve:
# ele passa o HTML por um parser, que descarta o form aninhado antes da
# asserção — o teste passaria justamente no caso quebrado.
class McpAccountBlockTest < ActionView::TestCase
  # Sem `tests`: ActionView::TestCase espera um MÓDULO de helpers, e
  # RedmineMcpServer::Hooks é uma classe (ViewListener). Passá-la faz
  # include_helper_modules! estourar TypeError antes do primeiro teste rodar.

  def setup
    Setting.plugin_redmine_mcp_server = {'enabled' => '1'}
    User.current = User.find(2)
  end

  def teardown
    User.current = nil
  end

  def render_block
    render partial: 'hooks/mcp_account_block'
    rendered.to_s
  end

  def test_o_bloco_nao_pode_emitir_form
    html = render_block
    refute_includes html, '<form', "o bloco vai dentro de um <form>; ver o comentário acima"
    refute_includes html, '<input type="submit"'
  end

  def test_o_bloco_leva_para_a_pagina_de_acesso
    assert_includes render_block, '/mcp/access'
  end

  def test_o_bloco_some_com_o_plugin_desligado
    Setting.plugin_redmine_mcp_server = {'enabled' => '0'}
    assert_equal '', render_block.strip
  end
end
