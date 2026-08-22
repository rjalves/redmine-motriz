require_relative '../test_helper'

class RedmineGoogleSso::ConfigTest < ActiveSupport::TestCase
  def setup
    Setting.plugin_redmine_google_sso = {
      'allowed_domains' => "motrizdigital.com.br\n@exemplo.com , OUTRO.COM",
      'auto_create' => '1',
      'enforce_twofa' => '0'
    }
  end

  def test_allowed_domains_normaliza_separadores_arroba_e_caixa
    assert_equal %w[motrizdigital.com.br exemplo.com outro.com],
                 RedmineGoogleSso::Config.allowed_domains
  end

  def test_allowed_domains_remove_duplicatas
    Setting.plugin_redmine_google_sso = {'allowed_domains' => "exemplo.com\nEXEMPLO.COM\n@exemplo.com"}
    assert_equal %w[exemplo.com], RedmineGoogleSso::Config.allowed_domains
  end

  def test_domain_allowed_compara_so_o_dominio_e_ignora_caixa
    assert RedmineGoogleSso::Config.domain_allowed?('Fulano@MotrizDigital.com.BR')
    refute RedmineGoogleSso::Config.domain_allowed?('fulano@gmail.com')
    refute RedmineGoogleSso::Config.domain_allowed?('sem-arroba')
    refute RedmineGoogleSso::Config.domain_allowed?(nil)
    refute RedmineGoogleSso::Config.domain_allowed?('')
  end

  def test_dominio_nao_casa_por_sufixo
    refute RedmineGoogleSso::Config.domain_allowed?('fulano@evilmotrizdigital.com.br')
  end

  def test_allowlist_vazia_bloqueia_tudo
    Setting.plugin_redmine_google_sso = {'allowed_domains' => ''}
    assert_empty RedmineGoogleSso::Config.allowed_domains
    refute RedmineGoogleSso::Config.domain_allowed?('fulano@motrizdigital.com.br')
    refute RedmineGoogleSso::Config.configured?
  end

  def test_configured_exige_credenciais_e_dominio
    with_env('GOOGLE_CLIENT_ID' => nil, 'GOOGLE_CLIENT_SECRET' => nil) do
      refute RedmineGoogleSso::Config.credentials?
      refute RedmineGoogleSso::Config.configured?
    end
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => nil) do
      refute RedmineGoogleSso::Config.configured?
    end
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      assert RedmineGoogleSso::Config.credentials?
      assert RedmineGoogleSso::Config.configured?
    end
  end

  def test_flags_booleanas_leem_1_como_verdadeiro
    assert RedmineGoogleSso::Config.auto_create?
    refute RedmineGoogleSso::Config.enforce_twofa?
  end

  def test_button_label_cai_para_traducao_quando_vazio
    Setting.plugin_redmine_google_sso = {'button_label' => ''}
    assert_equal I18n.t(:label_google_sso_button), RedmineGoogleSso::Config.button_label

    Setting.plugin_redmine_google_sso = {'button_label' => 'Entrar com a conta da empresa'}
    assert_equal 'Entrar com a conta da empresa', RedmineGoogleSso::Config.button_label
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
