require_relative '../test_helper'

class GoogleIdentityTest < ActiveSupport::TestCase
  def test_subject_e_unico
    GoogleIdentity.create!(user_id: 2, subject: 'sub-1', email: 'a@x.com')
    duplicata = GoogleIdentity.new(user_id: 3, subject: 'sub-1', email: 'b@x.com')
    refute duplicata.valid?
    assert_includes duplicata.errors.attribute_names, :subject
  end

  def test_exige_subject_e_usuario
    refute GoogleIdentity.new(subject: nil, user_id: 2).valid?
    refute GoogleIdentity.new(subject: 'sub-2', user_id: nil).valid?
  end

  def test_created_on_preenchido_automaticamente
    # O Rails trata created_on como timestamp de criação, igual a created_at.
    identidade = GoogleIdentity.create!(user_id: 2, subject: 'sub-3')
    assert_not_nil identidade.created_on
  end

  def test_record_login_atualiza_email_e_ultimo_acesso
    identidade = GoogleIdentity.create!(user_id: 2, subject: 'sub-4', email: 'antigo@x.com')
    identidade.record_login!('novo@x.com')
    identidade.reload
    assert_equal 'novo@x.com', identidade.email
    assert_not_nil identidade.last_login_on
  end

  def test_pertence_a_um_usuario
    identidade = GoogleIdentity.create!(user_id: 2, subject: 'sub-5')
    assert_equal User.find(2), identidade.user
  end
end
