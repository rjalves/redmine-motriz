require_relative '../test_helper'

class GoogleSsoSettingsTest < Redmine::ControllerTest
  tests SettingsController

  def setup
    @request.session[:user_id] = 1
  end

  def test_tela_de_configuracao_abre
    get :plugin, params: {id: 'redmine_google_sso'}
    assert_response :success
    assert_select 'textarea[name=?]', 'settings[allowed_domains]'
    assert_select 'input[type=checkbox][name=?]', 'settings[auto_create]'
    assert_select 'input[type=checkbox][name=?]', 'settings[enforce_twofa]'
    assert_select 'input[type=text][name=?]', 'settings[button_label]'
  end

  def test_checkbox_tem_hidden_para_desmarcar_persistir
    get :plugin, params: {id: 'redmine_google_sso'}
    assert_select 'input[type=hidden][name=?][value=?]', 'settings[auto_create]', '0'
    assert_select 'input[type=hidden][name=?][value=?]', 'settings[enforce_twofa]', '0'
  end

  def test_nao_expoe_campo_de_segredo
    get :plugin, params: {id: 'redmine_google_sso'}
    assert_select 'input[name=?]', 'settings[client_secret]', 0
    assert_select 'input[name=?]', 'settings[client_id]', 0
  end

  def test_salva_configuracao
    post :plugin, params: {
      id: 'redmine_google_sso',
      settings: {'allowed_domains' => 'exemplo.com', 'auto_create' => '1', 'enforce_twofa' => '0'}
    }
    assert_redirected_to '/settings/plugin/redmine_google_sso'
    assert_equal 'exemplo.com', Setting.plugin_redmine_google_sso['allowed_domains']
    assert_equal '1', Setting.plugin_redmine_google_sso['auto_create']
  end

  def test_desmarcar_checkbox_persiste
    post :plugin, params: {
      id: 'redmine_google_sso',
      settings: {'allowed_domains' => 'exemplo.com', 'auto_create' => '0'}
    }
    assert_equal '0', Setting.plugin_redmine_google_sso['auto_create']
    refute RedmineGoogleSso::Config.auto_create?
  end
end
