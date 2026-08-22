require_relative '../test_helper'

class GoogleSsoControllerTest < Redmine::ControllerTest
  include Redmine::I18n

  tests GoogleSsoController

  def setup
    User.current = nil
    Setting.plugin_redmine_google_sso = {
      'allowed_domains' => 'exemplo.com',
      'auto_create' => '1',
      'enforce_twofa' => '0'
    }
  end

  def test_callback_provisiona_e_autentica
    com_auth
    assert_difference('User.count', 1) { get :callback }
    assert_response :redirect
    assert_equal User.find_by_login('novo@exemplo.com').id, @request.session[:user_id]
  end

  def test_callback_respeita_back_url_valida
    com_auth(params: {'back_url' => 'http://test.host/issues'})
    get :callback
    assert_redirected_to 'http://test.host/issues'
  end

  def test_callback_ignora_back_url_para_host_externo
    com_auth(params: {'back_url' => 'http://evil.example.com/'})
    get :callback
    assert_redirected_to '/my/page'
  end

  def test_callback_recusa_dominio_de_fora
    com_auth(email: 'x@gmail.com')
    assert_no_difference('User.count') { get :callback }
    assert_redirected_to '/login'
    assert_nil @request.session[:user_id]
    assert_equal l(:notice_google_sso_denied), flash[:error]
  end

  def test_callback_recusa_email_nao_verificado
    com_auth(verified: false)
    get :callback
    assert_redirected_to '/login'
    assert_nil @request.session[:user_id]
  end

  def test_callback_sem_omniauth_auth_recusa
    get :callback
    assert_redirected_to '/login'
    assert_nil @request.session[:user_id]
  end

  def test_mensagem_de_recusa_nao_distingue_o_motivo
    com_auth(email: 'x@gmail.com')
    get :callback
    negado = flash[:error]

    com_auth(verified: false)
    get :callback
    assert_equal negado, flash[:error]
  end

  def test_callback_recusa_usuario_bloqueado
    bloqueado = User.find(2)
    bloqueado.mail = 'novo@exemplo.com'
    bloqueado.save!
    bloqueado.lock!

    com_auth
    get :callback
    assert_redirected_to '/login'
    assert_nil @request.session[:user_id]
  end

  def test_callback_pula_twofa_quando_reforco_desligado
    usuario = usuario_com_twofa
    com_auth
    get :callback
    assert_equal usuario.id, @request.session[:user_id]
  end

  def test_callback_exige_twofa_quando_reforco_ligado
    Setting.plugin_redmine_google_sso =
      Setting.plugin_redmine_google_sso.merge('enforce_twofa' => '1')
    usuario_com_twofa

    com_auth
    get :callback
    assert_redirected_to '/account/twofa/confirm'
    assert_nil @request.session[:user_id]
    assert_not_nil @request.session[:twofa_session_token]
  end

  def test_failure_redireciona_para_login_com_erro
    get :failure, params: {message: 'invalid_credentials'}
    assert_redirected_to '/login'
    assert_equal l(:notice_google_sso_denied), flash[:error]
  end

  private

  def com_auth(subject: 'sub-1', email: 'novo@exemplo.com', verified: true, params: {})
    @request.env['omniauth.auth'] = {
      'uid' => subject,
      'info' => {'email' => email, 'first_name' => 'Maria', 'last_name' => 'Silva'},
      'extra' => {'raw_info' => {'email_verified' => verified}}
    }
    @request.env['omniauth.params'] = params
  end

  # User#twofa_active? é só `twofa_scheme.present?`; gravar o esquema e a chave
  # direto evita depender do fluxo de pareamento, que é assunto do core.
  def usuario_com_twofa
    usuario = User.find(2)
    usuario.mail = 'novo@exemplo.com'
    usuario.twofa_scheme = 'totp'
    usuario.twofa_totp_key = ROTP::Base32.random
    usuario.save!
    assert usuario.twofa_active?
    usuario
  end
end
