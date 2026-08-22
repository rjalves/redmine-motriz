require_relative '../test_helper'

class GoogleSsoLoginButtonTest < Redmine::ControllerTest
  tests AccountController

  def setup
    User.current = nil
    Setting.plugin_redmine_google_sso = {'allowed_domains' => 'exemplo.com'}
  end

  def test_botao_aparece_quando_configurado
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      assert_response :success
      assert_select 'form[action^=?][method=post]', '/auth/google'
    end
  end

  def test_botao_some_sem_credenciais
    with_env('GOOGLE_CLIENT_ID' => nil, 'GOOGLE_CLIENT_SECRET' => nil) do
      get :login
      assert_response :success
      assert_select 'form[action^=?]', '/auth/google', 0
    end
  end

  def test_botao_some_sem_dominio_liberado
    Setting.plugin_redmine_google_sso = {'allowed_domains' => ''}
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      assert_response :success
      assert_select 'form[action^=?]', '/auth/google', 0
    end
  end

  def test_back_url_viaja_na_query_string
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login, params: {back_url: 'http://test.host/issues'}
      assert_response :success
      assert_select 'form[action=?]', '/auth/google?back_url=http%3A%2F%2Ftest.host%2Fissues'
    end
  end

  def test_formulario_de_senha_continua_na_tela
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      assert_select 'input[name=username]'
      assert_select 'input[name=password]'
    end
  end

  private

  def with_env(vars)
    antigos = vars.keys.to_h {|k| [k, ENV[k]]}
    vars.each {|k, v| v.nil? ? ENV.delete(k) : ENV[k] = v}
    yield
  ensure
    antigos.each {|k, v| v.nil? ? ENV.delete(k) : ENV[k] = v}
  end
end
