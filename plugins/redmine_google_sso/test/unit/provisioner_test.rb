require_relative '../test_helper'

class RedmineGoogleSso::ProvisionerTest < ActiveSupport::TestCase
  def setup
    Setting.plugin_redmine_google_sso = {
      'allowed_domains' => 'exemplo.com',
      'auto_create' => '1'
    }
  end

  def test_recusa_email_nao_verificado
    assert_equal :email_unverified, recusa(email_verified: false).reason
  end

  def test_recusa_email_ausente
    assert_equal :no_email, recusa(email: nil).reason
  end

  def test_recusa_subject_ausente
    assert_equal :no_email, recusa(subject: nil).reason
  end

  def test_recusa_dominio_fora_da_allowlist
    assert_equal :domain_denied, recusa(email: 'x@gmail.com').reason
  end

  def test_provisiona_usuario_novo_ja_ativo
    usuario = assert_difference('User.count', 1) { resolver }
    assert usuario.active?
    assert_equal 'novo@exemplo.com', usuario.login
    assert_equal 'novo@exemplo.com', usuario.mail
    assert_equal 'Maria', usuario.firstname
    assert_equal 'Silva', usuario.lastname
    assert_equal 1, GoogleIdentity.where(subject: 'sub-123', user_id: usuario.id).count
  end

  def test_usa_fallback_quando_google_nao_manda_nome
    usuario = resolver(first_name: nil, last_name: nil)
    assert_equal 'novo', usuario.firstname
    assert_equal '-', usuario.lastname
  end

  def test_casa_usuario_existente_por_email_e_cria_vinculo
    existente = User.find(2)
    existente.mail = 'novo@exemplo.com'
    existente.save!

    usuario = assert_no_difference('User.count') { resolver }
    assert_equal existente.id, usuario.id
    assert_equal existente.id, GoogleIdentity.find_by(subject: 'sub-123').user_id
  end

  def test_segunda_entrada_usa_o_subject_e_sobrevive_a_troca_de_email
    primeiro = resolver
    segundo = assert_no_difference('User.count') do
      resolver(email: 'trocado@exemplo.com')
    end
    assert_equal primeiro.id, segundo.id
    assert_equal 'trocado@exemplo.com', GoogleIdentity.find_by(subject: 'sub-123').email
  end

  def test_encontra_usuario_bloqueado_em_vez_de_duplicar
    bloqueado = User.find(2)
    bloqueado.mail = 'novo@exemplo.com'
    bloqueado.save!
    bloqueado.lock!

    usuario = assert_no_difference('User.count') { resolver }
    assert_equal bloqueado.id, usuario.id
    refute usuario.active?
  end

  def test_recusa_quando_auto_create_desligado_e_usuario_nao_existe
    Setting.plugin_redmine_google_sso = {'allowed_domains' => 'exemplo.com', 'auto_create' => '0'}
    assert_equal :no_account, recusa.reason
  end

  def test_login_longo_e_truncado_no_limite_do_core
    longo = "#{'a' * 70}@exemplo.com"
    usuario = resolver(email: longo)
    assert_equal User::LOGIN_LENGTH_LIMIT, usuario.login.length
    assert usuario.valid?
    assert_equal longo, usuario.mail
  end

  def test_login_colidido_ganha_sufixo
    User.generate!(login: 'novo@exemplo.com', mail: 'outro@exemplo.com')
    usuario = resolver
    assert_equal 'novo@exemplo.com-2', usuario.login
    assert_equal 'novo@exemplo.com', usuario.mail
  end

  def test_email_verified_aceita_string_e_numero
    assert RedmineGoogleSso::AuthPayload.new(email_verified: 'true').email_verified?
    assert RedmineGoogleSso::AuthPayload.new(email_verified: true).email_verified?
    assert RedmineGoogleSso::AuthPayload.new(email_verified: 1).email_verified?
    refute RedmineGoogleSso::AuthPayload.new(email_verified: 'false').email_verified?
    refute RedmineGoogleSso::AuthPayload.new(email_verified: nil).email_verified?
  end

  def test_from_omniauth_le_claims_de_info_e_raw_info
    payload = RedmineGoogleSso::AuthPayload.from_omniauth(
      'uid' => 'sub-9',
      'info' => {'email' => 'a@exemplo.com', 'first_name' => 'Ana', 'last_name' => 'Souza'},
      'extra' => {'raw_info' => {'email_verified' => true}}
    )
    assert_equal 'sub-9', payload.subject
    assert_equal 'a@exemplo.com', payload.email
    assert_equal 'Ana', payload.first_name
    assert_equal 'Souza', payload.last_name
    assert payload.email_verified?
  end

  def test_from_omniauth_cai_para_raw_info_quando_info_nao_traz_nome
    payload = RedmineGoogleSso::AuthPayload.from_omniauth(
      'uid' => 'sub-10',
      'info' => {'email' => 'b@exemplo.com'},
      'extra' => {'raw_info' => {'given_name' => 'Bia', 'family_name' => 'Lima',
                                 'email_verified' => 'true'}}
    )
    assert_equal 'Bia', payload.first_name
    assert_equal 'Lima', payload.last_name
  end

  private

  def payload(**sobrescrever)
    RedmineGoogleSso::AuthPayload.new(
      **{subject: 'sub-123', email: 'novo@exemplo.com', email_verified: true,
         first_name: 'Maria', last_name: 'Silva'}.merge(sobrescrever)
    )
  end

  def resolver(**sobrescrever)
    RedmineGoogleSso::Provisioner.new(payload(**sobrescrever)).call
  end

  def recusa(**sobrescrever)
    assert_raises(RedmineGoogleSso::Provisioner::Error) { resolver(**sobrescrever) }
  end
end
