# Plugin redmine_google_sso — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir login no Redmine 7.0.0 com conta Google corporativa, mantendo o login por senha.

**Architecture:** Middleware OmniAuth instalado por `config/additional_environment.rb`; um `GoogleSsoController < AccountController` recebe o callback e delega o login ao core. A resolução identidade→usuário fica isolada num `Provisioner` que **não conhece OmniAuth** (recebe um hash normalizado), para ser testável sem a gem.

**Tech Stack:** Redmine 7.0.0, Rails 8.1.3, Ruby 3.4, `omniauth-google-oauth2`, `omniauth-rails_csrf_protection`.

**Spec:** [docs/superpowers/specs/2026-08-21-google-sso-design.md](../specs/2026-08-21-google-sso-design.md)

## Global Constraints

- Redmine alvo: **7.0.0**. `requires_redmine version_or_higher: '7.0.0'`.
- Id do plugin e nome do diretório: **`redmine_google_sso`** (o core levanta `PluginNotFound` se divergirem).
- **Nunca** usar `require`/`require_dependency` para código do próprio plugin — Zeitwerk autoloada `app/*` e `lib/`. Referenciar a constante em `init.rb`.
- Nomes de arquivo em `assets/` são **achatados** para `plugin_assets/redmine_google_sso/<arquivo>` — únicos entre `images/`, `stylesheets/`, `javascripts/`.
- Credenciais **só** por `ENV['GOOGLE_CLIENT_ID']` / `ENV['GOOGLE_CLIENT_SECRET']`. Nenhum fallback para settings.
- Allowlist vazia = **nenhum login por SSO** (fail-closed).
- O plugin declara `Gemfile` próprio, copiado cedo no Dockerfile — mesmo padrão já usado no repositório para o plugin `motriz_2` (ver Task 7).
- Mensagem de erro ao usuário é **única** para toda recusa; o motivo real só no log.
- CSS em propriedades lógicas (`padding-inline`, `margin-block`), como o core.
- Ambiente de verificação: container `rm-app`. Ruby local é 2.6 e não roda Rails 8.

---

### Task 1: Esqueleto, i18n e `Config`

**Files:**
- Create: `plugins/redmine_google_sso/init.rb`
- Create: `plugins/redmine_google_sso/lib/redmine_google_sso/config.rb`
- Create: `plugins/redmine_google_sso/config/locales/en.yml`
- Create: `plugins/redmine_google_sso/config/locales/pt-BR.yml`
- Create: `plugins/redmine_google_sso/config/routes.rb`
- Test: `plugins/redmine_google_sso/test/unit/config_test.rb`
- Test: `plugins/redmine_google_sso/test/test_helper.rb`

**Interfaces:**
- Produces: `RedmineGoogleSso::Config` com `.client_id`, `.client_secret`, `.credentials?`, `.settings`, `.allowed_domains -> Array<String>`, `.domain_allowed?(email) -> Boolean`, `.auto_create? -> Boolean`, `.enforce_twofa? -> Boolean`, `.button_label -> String`, `.configured? -> Boolean`.

- [ ] **Step 1: Escrever o teste que falha**

```ruby
# plugins/redmine_google_sso/test/unit/config_test.rb
require_relative '../test_helper'

class RedmineGoogleSso::ConfigTest < ActiveSupport::TestCase
  def setup
    Setting.plugin_redmine_google_sso = {
      'allowed_domains' => "motrizdigital.com.br\n@exemplo.com , OUTRO.COM",
      'auto_create' => '1', 'enforce_twofa' => '0'
    }
  end

  def test_allowed_domains_normaliza_separadores_arroba_e_caixa
    assert_equal %w(motrizdigital.com.br exemplo.com outro.com),
                 RedmineGoogleSso::Config.allowed_domains
  end

  def test_domain_allowed_compara_so_o_dominio_e_ignora_caixa
    assert RedmineGoogleSso::Config.domain_allowed?('Fulano@MotrizDigital.com.BR')
    refute RedmineGoogleSso::Config.domain_allowed?('fulano@gmail.com')
    refute RedmineGoogleSso::Config.domain_allowed?('sem-arroba')
    refute RedmineGoogleSso::Config.domain_allowed?(nil)
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
      refute RedmineGoogleSso::Config.configured?
    end
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      assert RedmineGoogleSso::Config.configured?
    end
  end

  def test_flags_booleanas_leem_1_como_verdadeiro
    assert RedmineGoogleSso::Config.auto_create?
    refute RedmineGoogleSso::Config.enforce_twofa?
  end

  private

  def with_env(vars)
    antigos = vars.keys.index_with {|k| ENV[k]}
    vars.each {|k, v| v.nil? ? ENV.delete(k) : ENV[k] = v}
    yield
  ensure
    antigos.each {|k, v| v.nil? ? ENV.delete(k) : ENV[k] = v}
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:units NAME=redmine_google_sso
```
Esperado: FAIL — `uninitialized constant RedmineGoogleSso`.

- [ ] **Step 3: Implementar**

`test/test_helper.rb`:
```ruby
require_relative '../../../test/test_helper'
```

`lib/redmine_google_sso/config.rb`:
```ruby
# frozen_string_literal: true

module RedmineGoogleSso
  # Único ponto de leitura de configuração. Credenciais vêm exclusivamente do
  # ambiente: setting de plugin é serializada em texto puro na tabela settings.
  module Config
    module_function

    def client_id
      ENV['GOOGLE_CLIENT_ID'].presence
    end

    def client_secret
      ENV['GOOGLE_CLIENT_SECRET'].presence
    end

    def credentials?
      client_id.present? && client_secret.present?
    end

    def settings
      Setting.plugin_redmine_google_sso || {}
    end

    # Aceita separação por vírgula, ponto e vírgula ou quebra de linha, com ou
    # sem @ na frente. Sempre em caixa baixa.
    def allowed_domains
      settings['allowed_domains'].to_s
                                 .split(/[\s,;]+/)
                                 .map {|d| d.strip.downcase.delete_prefix('@')}
                                 .reject(&:blank?)
                                 .uniq
    end

    # Compara o domínio inteiro, nunca por sufixo: 'evilmotriz.com.br' não pode
    # passar por causa de 'motriz.com.br' estar na lista.
    def domain_allowed?(email)
      domain = email.to_s.downcase.split('@').last
      return false if domain.blank? || !email.to_s.include?('@')

      allowed_domains.include?(domain)
    end

    def auto_create?
      settings['auto_create'].to_s == '1'
    end

    def enforce_twofa?
      settings['enforce_twofa'].to_s == '1'
    end

    def button_label
      settings['button_label'].presence || I18n.t(:label_google_sso_button)
    end

    # Fail-closed: sem credenciais OU sem domínio liberado, o SSO não existe.
    def configured?
      credentials? && allowed_domains.any?
    end
  end
end
```

`init.rb`:
```ruby
Redmine::Plugin.register :redmine_google_sso do
  name        'Redmine Google SSO'
  author      'Roberto Alves'
  description 'Login com conta Google corporativa, com allowlist de domínio'
  version     '0.1.0'
  url         'https://github.com/rjalves/redmine_google_sso'
  requires_redmine version_or_higher: '7.0.0'

  settings default: {
             'allowed_domains' => '',
             'auto_create'     => '1',
             'enforce_twofa'   => '0',
             'button_label'    => ''
           },
           partial: 'settings/redmine_google_sso_settings'
end
```

`config/routes.rb`:
```ruby
# O middleware OmniAuth trata /auth/google (request) e /auth/google/callback
# (callback) e então repassa a requisição para o Rails — por isso o callback
# precisa de rota. /auth/failure é o on_failure padrão do OmniAuth.
match 'auth/google/callback', to: 'google_sso#callback', via: [:get, :post], as: 'google_sso_callback'
match 'auth/failure',         to: 'google_sso#failure',  via: [:get, :post], as: 'google_sso_failure'
```

`config/locales/pt-BR.yml`:
```yaml
pt-BR:
  label_google_sso: SSO com Google
  label_google_sso_button: Entrar com Google
  label_google_sso_allowed_domains: Domínios permitidos
  label_google_sso_auto_create: Criar usuário no primeiro acesso
  label_google_sso_enforce_twofa: Exigir o 2FA do Redmine também
  label_google_sso_button_label: Rótulo do botão
  text_google_sso_allowed_domains: Um por linha. Vazio bloqueia todo login por Google.
  text_google_sso_credentials_missing: Defina GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET no ambiente.
  text_google_sso_credentials_ok: Credenciais encontradas no ambiente.
  notice_google_sso_denied: Não foi possível entrar com esta conta Google.
```

`config/locales/en.yml` — mesmas chaves em inglês.

- [ ] **Step 4: Rodar e ver passar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:units NAME=redmine_google_sso
```
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/redmine_google_sso
git commit -m "Esqueleto do plugin de SSO com Google e leitura de configuração"
```

---

### Task 2: Migration e `GoogleIdentity`

**Files:**
- Create: `plugins/redmine_google_sso/db/migrate/20260821120000_create_google_identities.rb`
- Create: `plugins/redmine_google_sso/app/models/google_identity.rb`
- Test: `plugins/redmine_google_sso/test/unit/google_identity_test.rb`

**Interfaces:**
- Produces: `GoogleIdentity` (`user_id`, `subject`, `email`, `created_on`, `last_login_on`), `#record_login!(email)`.

- [ ] **Step 1: Escrever o teste que falha**

```ruby
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
    # Rails trata created_on como timestamp de criação, igual a created_at.
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
end
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:units NAME=redmine_google_sso
```
Esperado: FAIL — `uninitialized constant GoogleIdentity`.

- [ ] **Step 3: Implementar**

```ruby
# db/migrate/20260821120000_create_google_identities.rb
class CreateGoogleIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :google_identities do |t|
      t.integer  :user_id, null: false
      t.string   :subject, null: false
      t.string   :email
      t.datetime :created_on
      t.datetime :last_login_on
    end
    add_index :google_identities, :subject, unique: true
    add_index :google_identities, :user_id
  end
end
```

```ruby
# app/models/google_identity.rb
# frozen_string_literal: true

# Vínculo entre um usuário do Redmine e uma identidade Google.
#
# Guardamos o `sub` (não o e-mail) porque ele é o identificador estável do
# Google: trocar o e-mail de alguém no Workspace não quebra o vínculo, e
# ninguém herda uma conta do Redmine ao receber um endereço reciclado.
class GoogleIdentity < ApplicationRecord
  belongs_to :user

  validates :subject, presence: true, uniqueness: true
  validates :user_id, presence: true

  def record_login!(email)
    update_columns(email: email, last_login_on: Time.current)
  end
end
```

- [ ] **Step 4: Migrar, rodar e ver passar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:migrate NAME=redmine_google_sso
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:units NAME=redmine_google_sso
```
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/redmine_google_sso
git commit -m "Tabela e modelo de vínculo com a identidade Google"
```

---

### Task 3: `AuthPayload` e `Provisioner`

O `Provisioner` **não conhece OmniAuth**: recebe um `AuthPayload`. Toda a dependência do formato da gem fica confinada em `AuthPayload.from_omniauth`, que é o único ponto a conferir contra a gem instalada.

**Files:**
- Create: `plugins/redmine_google_sso/lib/redmine_google_sso/auth_payload.rb`
- Create: `plugins/redmine_google_sso/lib/redmine_google_sso/provisioner.rb`
- Test: `plugins/redmine_google_sso/test/unit/provisioner_test.rb`

**Interfaces:**
- Produces: `RedmineGoogleSso::AuthPayload` (Struct com `subject`, `email`, `email_verified`, `first_name`, `last_name`; `.from_omniauth(auth)`; `#email_verified?`).
- Produces: `RedmineGoogleSso::Provisioner.new(payload).call -> User`, levanta `RedmineGoogleSso::Provisioner::Error` com `#reason` em `:no_email | :email_unverified | :domain_denied | :no_account | :login_collision`.

- [ ] **Step 1: Escrever o teste que falha**

```ruby
require_relative '../test_helper'

class RedmineGoogleSso::ProvisionerTest < ActiveSupport::TestCase
  def setup
    Setting.plugin_redmine_google_sso = {
      'allowed_domains' => 'exemplo.com', 'auto_create' => '1'
    }
  end

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

  def test_recusa_email_nao_verificado
    assert_equal :email_unverified, recusa(email_verified: false).reason
  end

  def test_recusa_email_ausente
    assert_equal :no_email, recusa(email: nil).reason
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

  def test_segunda_entrada_usa_o_subject_e_ignora_troca_de_email
    primeiro = resolver
    segundo = assert_no_difference('User.count') do
      RedmineGoogleSso::Provisioner.new(payload(email: 'trocado@exemplo.com')).call
    end
    assert_equal primeiro.id, segundo.id
    assert_equal 'trocado@exemplo.com', GoogleIdentity.find_by(subject: 'sub-123').email
  end

  def test_encontra_usuario_bloqueado_em_vez_de_duplicar
    bloqueado = User.find(2)
    bloqueado.mail = 'novo@exemplo.com'
    bloqueado.lock!
    bloqueado.save!

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
  end

  def test_login_colidido_ganha_sufixo
    User.generate!(login: 'novo@exemplo.com', mail: 'outro@exemplo.com')
    usuario = resolver
    assert_equal 'novo@exemplo.com-2', usuario.login
    assert_equal 'novo@exemplo.com', usuario.mail
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:units NAME=redmine_google_sso
```
Esperado: FAIL — `uninitialized constant RedmineGoogleSso::AuthPayload`.

- [ ] **Step 3: Implementar**

```ruby
# lib/redmine_google_sso/auth_payload.rb
# frozen_string_literal: true

module RedmineGoogleSso
  # Fronteira com a gem. Todo o resto do plugin fala este Struct, nunca o
  # AuthHash do OmniAuth — é o que mantém o Provisioner testável sem a gem.
  AuthPayload = Struct.new(:subject, :email, :email_verified, :first_name, :last_name,
                           keyword_init: true) do
    # `email_verified` chega como true, "true" ou 1 conforme o caminho que a
    # strategy usou (id_token decodificado x userinfo). Normaliza tudo aqui.
    def email_verified?
      %w(true 1).include?(email_verified.to_s.downcase)
    end

    def self.from_omniauth(auth)
      info = auth['info'] || {}
      raw  = auth.dig('extra', 'raw_info') || {}
      new(
        subject:        auth['uid'].presence,
        email:          (info['email'] || raw['email']).presence,
        email_verified: raw.key?('email_verified') ? raw['email_verified'] : info['email_verified'],
        first_name:     (info['first_name'] || raw['given_name']).presence,
        last_name:      (info['last_name'] || raw['family_name']).presence
      )
    end
  end
end
```

```ruby
# lib/redmine_google_sso/provisioner.rb
# frozen_string_literal: true

module RedmineGoogleSso
  # Resolve um AuthPayload para um User do Redmine, criando o vínculo e, se
  # permitido, o próprio usuário. Não decide sobre sessão nem 2FA: isso é do
  # controller.
  class Provisioner
    class Error < StandardError
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super(reason.to_s)
      end
    end

    def initialize(payload)
      @payload = payload
    end

    def call
      validar!

      identidade = GoogleIdentity.find_by(subject: @payload.subject)
      unless identidade
        usuario = usuario_existente || provisionar
        raise Error, :no_account if usuario.nil?

        identidade = GoogleIdentity.create!(
          user: usuario, subject: @payload.subject, email: @payload.email
        )
      end

      identidade.record_login!(@payload.email)
      identidade.user
    end

    private

    def validar!
      raise Error, :no_email          if @payload.subject.blank? || @payload.email.blank?
      raise Error, :email_unverified  unless @payload.email_verified?
      raise Error, :domain_denied     unless Config.domain_allowed?(@payload.email)
    end

    # Sem escopo .active de propósito: se houver um usuário bloqueado com este
    # e-mail, queremos encontrá-lo e deixar o controller recusar, em vez de
    # criar um duplicado.
    def usuario_existente
      User.find_by_mail(@payload.email)
    end

    def provisionar
      return nil unless Config.auto_create?

      usuario = User.new(
        login:     login_disponivel,
        mail:      @payload.email,
        firstname: @payload.first_name.presence || @payload.email.split('@').first,
        lastname:  @payload.last_name.presence  || '-',
        language:  Setting.default_language
      )
      usuario.random_password
      usuario.activate
      usuario.save!
      usuario
    end

    def login_disponivel
      base = @payload.email.downcase[0, User::LOGIN_LENGTH_LIMIT]
      return base unless User.find_by_login(base)

      2.upto(99) do |n|
        sufixo = "-#{n}"
        candidato = "#{base[0, User::LOGIN_LENGTH_LIMIT - sufixo.length]}#{sufixo}"
        return candidato unless User.find_by_login(candidato)
      end
      raise Error, :login_collision
    end
  end
end
```

- [ ] **Step 4: Rodar e ver passar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:units NAME=redmine_google_sso
```
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/redmine_google_sso
git commit -m "Resolução de identidade Google para usuário do Redmine"
```

---

### Task 4: `GoogleSsoController`

**Files:**
- Create: `plugins/redmine_google_sso/app/controllers/google_sso_controller.rb`
- Test: `plugins/redmine_google_sso/test/functional/google_sso_controller_test.rb`

**Interfaces:**
- Consumes: `RedmineGoogleSso::AuthPayload.from_omniauth`, `RedmineGoogleSso::Provisioner#call`, `RedmineGoogleSso::Config.enforce_twofa?`.
- Produces: ações `callback` e `failure`.

- [ ] **Step 1: Escrever o teste que falha**

```ruby
require_relative '../test_helper'

class GoogleSsoControllerTest < Redmine::ControllerTest
  tests GoogleSsoController

  def setup
    User.current = nil
    Setting.plugin_redmine_google_sso = {
      'allowed_domains' => 'exemplo.com', 'auto_create' => '1', 'enforce_twofa' => '0'
    }
  end

  def com_auth(subject: 'sub-1', email: 'novo@exemplo.com', verified: true, params: {})
    @request.env['omniauth.auth'] = {
      'uid' => subject,
      'info' => {'email' => email, 'first_name' => 'Maria', 'last_name' => 'Silva'},
      'extra' => {'raw_info' => {'email_verified' => verified}}
    }
    @request.env['omniauth.params'] = params
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

  def test_callback_recusa_usuario_bloqueado
    bloqueado = User.find(2)
    bloqueado.mail = 'novo@exemplo.com'
    bloqueado.lock!
    bloqueado.save!

    com_auth
    get :callback
    assert_redirected_to '/login'
    assert_nil @request.session[:user_id]
  end

  def test_callback_pula_twofa_quando_reforco_desligado
    usuario = User.find(2)
    usuario.mail = 'novo@exemplo.com'
    usuario.update!(twofa_scheme: 'totp', twofa_totp_key: '1' * 32)

    com_auth
    get :callback
    assert_equal usuario.id, @request.session[:user_id]
  end

  def test_callback_exige_twofa_quando_reforco_ligado
    Setting.plugin_redmine_google_sso =
      Setting.plugin_redmine_google_sso.merge('enforce_twofa' => '1')
    usuario = User.find(2)
    usuario.mail = 'novo@exemplo.com'
    usuario.update!(twofa_scheme: 'totp', twofa_totp_key: '1' * 32)

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
end
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:functionals NAME=redmine_google_sso
```
Esperado: FAIL — `uninitialized constant GoogleSsoController`.

- [ ] **Step 3: Implementar**

```ruby
# app/controllers/google_sso_controller.rb
# frozen_string_literal: true

# Herda de AccountController para reaproveitar o caminho de login do core:
#
#   * skip_before_action :check_if_login_required — sem isso, com
#     Setting.login_required ligado o callback entra em loop de redirect;
#   * successful_authentication — faz reset_session, dispara o hook
#     controller_account_success_authentication_after e respeita back_url;
#   * setup_twofa_session — grava o Token que o twofa_setup do core lê, o que
#     devolve o fluxo de 2FA inteiro ao core;
#   * handle_inactive_user — trata bloqueado e pendente como no login por senha.
class GoogleSsoController < AccountController
  def callback
    auth = request.env['omniauth.auth']
    return recusar(:missing_auth) if auth.blank?

    propagar_back_url
    usuario = RedmineGoogleSso::Provisioner.new(
      RedmineGoogleSso::AuthPayload.from_omniauth(auth)
    ).call

    return handle_inactive_user(usuario, signin_path) unless usuario.active?

    if usuario.twofa_active? && RedmineGoogleSso::Config.enforce_twofa?
      exigir_twofa(usuario)
    else
      if usuario.twofa_active?
        logger.info "SSO Google: 2FA do Redmine pulado para '#{usuario.login}' " \
                    "(enforce_twofa desligado)"
      end
      successful_authentication(usuario)
    end
  rescue RedmineGoogleSso::Provisioner::Error => e
    recusar(e.reason)
  end

  def failure
    recusar(params[:message].presence || 'omniauth_failure')
  end

  private

  # O callback não recebe os params originais do botão. O OmniAuth preserva a
  # query string da fase de request em omniauth.params; copiamos de volta para
  # params porque é de lá que successful_authentication e setup_twofa_session
  # leem. A validação contra open redirect continua sendo a do core.
  def propagar_back_url
    back_url = request.env['omniauth.params'].try(:[], 'back_url')
    params[:back_url] = back_url if back_url.present?
  end

  def exigir_twofa(usuario)
    setup_twofa_session(usuario)
    twofa = Redmine::Twofa.for_user(usuario)
    flash[:notice] = l('twofa_code_sent') if twofa.send_code(controller: 'account', action: 'twofa')
    redirect_to account_twofa_confirm_path
  end

  # Mensagem única para toda recusa: distinguir "domínio negado" de "conta
  # inexistente" transformaria a tela de login num oráculo de enumeração.
  # O motivo real fica só no log.
  def recusar(motivo)
    logger.warn "SSO Google recusado (#{motivo}) de #{request.remote_ip} em #{Time.now.utc}"
    flash[:error] = l(:notice_google_sso_denied)
    redirect_to signin_path
  end
end
```

- [ ] **Step 4: Rodar e ver passar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:functionals NAME=redmine_google_sso
```
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/redmine_google_sso
git commit -m "Controller do callback de SSO, delegando o login ao core"
```

---

### Task 5: Botão na tela de login

**Files:**
- Create: `plugins/redmine_google_sso/lib/redmine_google_sso/hooks.rb`
- Create: `plugins/redmine_google_sso/app/views/hooks/_google_sso_login_button.html.erb`
- Create: `plugins/redmine_google_sso/assets/stylesheets/google_sso.css`
- Modify: `plugins/redmine_google_sso/init.rb` (referenciar a constante do hook)
- Test: `plugins/redmine_google_sso/test/functional/login_button_test.rb`

**Interfaces:**
- Consumes: `RedmineGoogleSso::Config.configured?`, `.button_label`.
- Produces: `RedmineGoogleSso::Hooks < Redmine::Hook::ViewListener`.

- [ ] **Step 1: Escrever o teste que falha**

```ruby
require_relative '../test_helper'

class GoogleSsoLoginButtonTest < Redmine::ControllerTest
  tests AccountController

  def setup
    User.current = nil
    Setting.plugin_redmine_google_sso = {'allowed_domains' => 'exemplo.com'}
  end

  def with_env(vars)
    antigos = vars.keys.index_with {|k| ENV[k]}
    vars.each {|k, v| v.nil? ? ENV.delete(k) : ENV[k] = v}
    yield
  ensure
    antigos.each {|k, v| v.nil? ? ENV.delete(k) : ENV[k] = v}
  end

  def test_botao_aparece_quando_configurado
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login
      assert_response :success
      assert_select 'form[action^=?]', '/auth/google'
      assert_select 'form[method=post]'
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
      assert_select 'form[action^=?]', '/auth/google', 0
    end
  end

  def test_back_url_viaja_na_query_string
    with_env('GOOGLE_CLIENT_ID' => 'id', 'GOOGLE_CLIENT_SECRET' => 'segredo') do
      get :login, params: {back_url: 'http://test.host/issues'}
      assert_select 'form[action=?]', '/auth/google?back_url=http%3A%2F%2Ftest.host%2Fissues'
    end
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:functionals NAME=redmine_google_sso
```
Esperado: FAIL — nenhum `form[action^=/auth/google]`.

- [ ] **Step 3: Implementar**

```ruby
# lib/redmine_google_sso/hooks.rb
# frozen_string_literal: true

module RedmineGoogleSso
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_account_login_bottom, partial: 'hooks/google_sso_login_button'

    def view_layouts_base_html_head(context = {})
      return '' unless Config.configured?

      stylesheet_link_tag('google_sso', plugin: 'redmine_google_sso')
    end
  end
end
```

```erb
<%# app/views/hooks/_google_sso_login_button.html.erb %>
<% if RedmineGoogleSso::Config.configured? %>
  <%#
    O POST vai direto ao middleware OmniAuth, então nenhuma action do Rails roda
    antes — o back_url tem que viajar na query string, que é o que o OmniAuth
    guarda em omniauth.params. O token CSRF do form é validado pela gem
    omniauth-rails_csrf_protection.
  %>
  <% inicio = "#{Redmine::Utils.relative_url_root}/auth/google" %>
  <% inicio += "?#{{'back_url' => params[:back_url]}.to_query}" if params[:back_url].present? %>
  <div id="google-sso">
    <span class="google-sso-separator"><%= l(:label_google_sso) %></span>
    <%= button_to RedmineGoogleSso::Config.button_label, inicio, class: 'google-sso-button' %>
  </div>
<% end %>
```

```css
/* assets/stylesheets/google_sso.css */
#google-sso {
  margin-block-start: 1em;
  padding-block-start: 1em;
  border-block-start: 1px solid var(--oc-gray-3, #dee2e6);
  text-align: center;
}

#google-sso .google-sso-separator {
  display: block;
  margin-block-end: .5em;
  font-size: .9em;
  color: var(--oc-gray-6, #868e96);
}

#google-sso form { display: inline; }

#google-sso .google-sso-button {
  padding-block: .5em;
  padding-inline: 1.2em;
  border: 1px solid var(--oc-gray-4, #ced4da);
  border-radius: 3px;
  background: var(--oc-white, #fff);
  color: var(--oc-gray-8, #343a40);
  cursor: pointer;
  font-size: 1em;
}

#google-sso .google-sso-button:hover {
  background: var(--oc-gray-1, #f1f3f5);
}
```

Acrescentar ao fim do `init.rb`:
```ruby
# Referenciar a constante basta: o Zeitwerk carrega lib/redmine_google_sso/hooks.rb
# e o `inherited` de Listener registra o hook. Nada de require aqui.
RedmineGoogleSso::Hooks
```

- [ ] **Step 4: Rodar e ver passar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:functionals NAME=redmine_google_sso
```
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/redmine_google_sso
git commit -m "Botão de entrar com Google na tela de login"
```

---

### Task 6: Tela de configuração do plugin

**Files:**
- Create: `plugins/redmine_google_sso/app/views/settings/_redmine_google_sso_settings.html.erb`
- Test: `plugins/redmine_google_sso/test/functional/settings_test.rb`

**Interfaces:**
- Consumes: `RedmineGoogleSso::Config.credentials?`.

- [ ] **Step 1: Escrever o teste que falha**

```ruby
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
  end

  def test_checkbox_tem_hidden_para_desmarcar_persistir
    get :plugin, params: {id: 'redmine_google_sso'}
    assert_select 'input[type=hidden][name=?][value=0]', 'settings[auto_create]'
    assert_select 'input[type=hidden][name=?][value=0]', 'settings[enforce_twofa]'
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
  end
end
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:functionals NAME=redmine_google_sso
```
Esperado: FAIL — partial inexistente.

- [ ] **Step 3: Implementar**

```erb
<%# app/views/settings/_redmine_google_sso_settings.html.erb %>
<p>
  <label><%= l(:label_google_sso) %></label>
  <% if RedmineGoogleSso::Config.credentials? %>
    <span class="icon icon-ok"><%= l(:text_google_sso_credentials_ok) %></span>
  <% else %>
    <span class="icon icon-warning"><%= l(:text_google_sso_credentials_missing) %></span>
  <% end %>
</p>

<p>
  <label for="settings_allowed_domains"><%= l(:label_google_sso_allowed_domains) %></label>
  <%= text_area_tag 'settings[allowed_domains]', settings['allowed_domains'],
                    :id => 'settings_allowed_domains', :rows => 4, :cols => 40 %>
  <em class="info"><%= l(:text_google_sso_allowed_domains) %></em>
</p>

<%#
  O hidden antes do checkbox é obrigatório: SettingsController#plugin grava o
  hash inteiro do POST, então campo ausente simplesmente some da configuração e
  desmarcar nunca persistiria.
%>
<p>
  <label for="settings_auto_create"><%= l(:label_google_sso_auto_create) %></label>
  <%= hidden_field_tag 'settings[auto_create]', 0, :id => nil %>
  <%= check_box_tag 'settings[auto_create]', 1, settings['auto_create'].to_s == '1',
                    :id => 'settings_auto_create' %>
</p>

<p>
  <label for="settings_enforce_twofa"><%= l(:label_google_sso_enforce_twofa) %></label>
  <%= hidden_field_tag 'settings[enforce_twofa]', 0, :id => nil %>
  <%= check_box_tag 'settings[enforce_twofa]', 1, settings['enforce_twofa'].to_s == '1',
                    :id => 'settings_enforce_twofa' %>
</p>

<p>
  <label for="settings_button_label"><%= l(:label_google_sso_button_label) %></label>
  <%= text_field_tag 'settings[button_label]', settings['button_label'],
                     :id => 'settings_button_label', :size => 40 %>
</p>
```

- [ ] **Step 4: Rodar e ver passar**

```bash
docker exec -w /redmine rm-app bundle exec rake redmine:plugins:test:functionals NAME=redmine_google_sso
```
Esperado: PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/redmine_google_sso
git commit -m "Tela de configuração do plugin de SSO"
```

---

### Task 7: Middleware, Docker e README

Esta é a tarefa que liga tudo: sem o middleware, `/auth/google` não existe.

**Files:**
- Create: `redmine-7/config/additional_environment.rb`
- Modify: `Dockerfile` (bloco do `Gemfile.local`; `COPY` do plugin; cópia do `additional_environment.rb`)
- Modify: `.env.example` (as duas variáveis)
- Create: `plugins/redmine_google_sso/README.md`

- [ ] **Step 1: Escrever o `additional_environment.rb`**

```ruby
# redmine-7/config/additional_environment.rb
#
# Este arquivo é lido por config/application.rb com instance_eval DENTRO do
# corpo da classe Application, em tempo de config — antes do
# build_middleware_stack do Rails. É o único lugar de onde um plugin consegue
# instalar middleware Rack, porque init.rb roda em to_prepare, tarde demais.

require 'omniauth'
require 'omniauth-google-oauth2'
require 'omniauth/rails_csrf_protection'

OmniAuth.config.logger = Rails.logger

# Sem credenciais o middleware não é instalado e o boot segue normalmente; o
# plugin detecta a ausência e esconde o botão. Derrubar o Redmine porque falta
# uma variável de ambiente seria pior que não ter SSO.
if ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
  config.middleware.use OmniAuth::Builder do
    provider :google_oauth2,
             ENV['GOOGLE_CLIENT_ID'],
             ENV['GOOGLE_CLIENT_SECRET'],
             name: 'google',
             scope: 'email,profile',
             prompt: 'select_account',
             access_type: 'online',
             setup: lambda {|env|
               # `hd` é dica de UI para o Google, não garantia: a validação de
               # domínio que vale é a do Provisioner, no servidor.
               dominios = RedmineGoogleSso::Config.allowed_domains
               env['omniauth.strategy'].options[:hd] = dominios.first if dominios.size == 1
             }
  end
end

config.filter_parameters += [:code, :id_token, :access_token, :refresh_token, :client_secret]
```

- [ ] **Step 2: Alterar o Dockerfile**

No `RUN` que hoje gera o `Gemfile.local` só com o Puma:

```dockerfile
# O plugin de SSO NÃO declara Gemfile próprio: o `bundle install` acontece antes
# do COPY da árvore, então o glob `plugins/*/Gemfile` do Gemfile do core não
# enxergaria o plugin no build — e em runtime o bundler acusaria Gemfile
# alterado a cada `bundle exec`. Gemfile.local é o ponto de extensão certo.
RUN printf "%s\n" \
      "gem 'puma'" \
      "gem 'omniauth-google-oauth2'" \
      "gem 'omniauth-rails_csrf_protection'" \
      > Gemfile.local
```

Depois do `COPY redmine-7/ $REDMINE_HOME/`:

```dockerfile
COPY plugins/redmine_google_sso/ $REDMINE_HOME/plugins/redmine_google_sso/
```

- [ ] **Step 3: Verificar que o build resolve as gems**

```bash
docker compose build redmine
```
Esperado: build conclui; `omniauth-google-oauth2` e `omniauth-rails_csrf_protection` aparecem no bundle.

- [ ] **Step 4: Subir e conferir a rota e o boot**

```bash
docker compose up -d
docker compose logs redmine | tail -30
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost/login
```
Esperado: boot sem erro, `/login` responde 200.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile .env.example redmine-7/config/additional_environment.rb plugins/redmine_google_sso/README.md
git commit -m "Middleware OmniAuth e integração do plugin de SSO no build"
```

---

## Self-Review

**Cobertura do spec:**

| Requisito do spec | Task |
|---|---|
| §3 componentes | 1–7 |
| §4 fluxo e ordem de decisão | 3 (validação) + 4 (sessão/2FA) |
| §4.1 propagação de `back_url` | 4 (`propagar_back_url`) + 5 (query string) |
| §5 modelo de dados | 2 |
| §5.1 provisionamento | 3 |
| §6.1 middleware | 7 |
| §6.2 Docker | 7 |
| §6.3 variáveis de ambiente | 1 (`Config`) + 7 (`.env.example`) |
| §6.4 settings | 1 (defaults) + 6 (tela) |
| §7 segurança | 3, 4, 7 (`filter_parameters`) |
| §8 testes | todas |
| §10.1 nomes de claim | 3 (`AuthPayload.from_omniauth` isola) |
| §10.4 limite de login | 3 (`login_disponivel`) |

**Consistência de tipos:** `AuthPayload` é produzido em Task 3 e consumido em Task 4 com os mesmos nomes de campo. `Config.enforce_twofa?`/`auto_create?`/`configured?` usados em 3, 4, 5, 6 com a assinatura definida em 1. `GoogleIdentity#record_login!` definido em 2 e chamado em 3.

**Sem placeholders:** todo passo traz código real.

**Lacuna assumida:** o teste do Task 7 é manual (build + curl). Não há teste automatizado do `additional_environment.rb` porque ele roda em tempo de boot, fora do alcance do harness de teste do Redmine.
