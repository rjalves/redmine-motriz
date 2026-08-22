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

  # O tema Motriz carrega Turbo. Sem data-turbo="false" o Turbo intercepta o
  # submit, faz fetch() e recebe um 302 para accounts.google.com — outra origem,
  # que ele não segue. O clique não faz nada e nenhum erro aparece.
  def test_form_desliga_o_turbo
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      assert_select 'form[action^=?][data-turbo=?]', '/auth/google', 'false'
    end
  end

  # button_to com rótulo em string gera <input type="submit">, que é elemento
  # vazio e não aceita imagem dentro. Para ter o logotipo o form precisa da
  # forma de bloco, que gera <button>.
  def test_botao_e_um_button_com_o_logotipo_dentro
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      assert_select 'form[action^=?]', '/auth/google' do
        assert_select 'button[type=submit].google-sso-button' do
          assert_select 'svg.google-sso-icon', 1
          assert_select 'span.google-sso-label', text: RedmineGoogleSso::Config.button_label
        end
        assert_select 'input[type=submit]', 0
      end
    end
  end

  def test_logotipo_traz_as_quatro_cores_oficiais_do_google
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      %w[#EA4335 #4285F4 #FBBC05 #34A853].each do |cor|
        assert_select "svg.google-sso-icon path[fill=?]", cor, 1,
                      "faltou o traçado #{cor} do logotipo"
      end
    end
  end

  # O ícone é decorativo: o texto ao lado já nomeia a ação, então repetir no
  # leitor de tela seria ruído.
  def test_icone_e_escondido_de_leitor_de_tela
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      assert_select 'svg.google-sso-icon[aria-hidden=true]', 1
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
