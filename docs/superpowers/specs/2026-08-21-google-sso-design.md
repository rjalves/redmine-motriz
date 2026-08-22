# Design — Plugin de SSO com Google para Redmine 7.0.0

Data: 21/08/2026
Alvo: Redmine 7.0.0 stable (árvore em `redmine-7/`), Rails 8.1.3, Ruby 3.4, Propshaft.
Plugin: `redmine_google_sso`

## 1. Objetivo

Permitir que colaboradores entrem no Redmine com a conta Google corporativa, sem
criar senha, mantendo o login por senha em funcionamento para quem precisar.

## 2. Decisões tomadas

| Questão | Decisão |
|---|---|
| Quem pode entrar | Allowlist de domínios configurada pelo admin |
| Primeiro login sem conta | Provisiona automaticamente, já ativo |
| Login por senha | Continua existindo; os dois convivem na tela |
| 2FA do Redmine sobre o SSO | Configurável pelo admin; **default: pular** |
| Implementação do protocolo | `omniauth-google-oauth2` (não OIDC na mão) |
| Credenciais | **Exclusivamente por variável de ambiente** |

### 2.1 Por que OmniAuth e não OIDC na mão

Menos código de protocolo próprio numa superfície de segurança. O custo — instalar
middleware Rack a partir de um plugin — é pagável porque o Redmine tem um ponto de
extensão oficial para isso (ver 6.1); não é preciso editar fonte do core.

### 2.2 Por que herdar de `AccountController`

`GoogleSsoController < AccountController` recebe de graça:

- `skip_before_action :check_if_login_required, :check_password_change` — sem isso,
  com `Setting.login_required` ligado, o callback entra em loop de redirect;
- `successful_authentication(user)` — faz `logged_user=` (que por sua vez faz
  `reset_session` + `start_user_session`), dispara o hook
  `controller_account_success_authentication_after` e respeita `back_url`;
- `setup_twofa_session(user)` — grava um `Token` de ação `twofa_session`; o
  `twofa_setup` do core recupera o usuário dele. É o que permite **devolver o fluxo
  de 2FA ao core intacto**, sem reimplementar tela nem contador de tentativas;
- `handle_inactive_user`, `account_pending`, `account_locked`;
- `self.main_menu = false`.

Risco aceito: são métodos privados do core. Um upgrade do Redmine pode mudá-los.
Mitigação: testes funcionais cobrindo cada caminho, e `requires_redmine` fixando
a faixa de versão suportada.

## 3. Componentes

```
plugins/redmine_google_sso/
├─ init.rb                                     register, settings, wiring do hook
├─ README.md                                   instalação e configuração
├─ config/
│  ├─ routes.rb
│  └─ locales/{en,pt-BR}.yml
├─ app/
│  ├─ controllers/google_sso_controller.rb     < AccountController
│  ├─ models/google_identity.rb
│  └─ views/
│     ├─ settings/_redmine_google_sso_settings.html.erb
│     └─ hooks/_login_button.html.erb
├─ lib/redmine_google_sso/
│  ├─ config.rb                                leitura de ENV + settings, num lugar só
│  ├─ provisioner.rb                           resolve identidade → User
│  └─ hooks.rb                                 ViewListener
├─ db/migrate/…_create_google_identities.rb
├─ assets/stylesheets/google_sso.css
└─ test/{unit,functional}/

config/additional_environment.rb               middleware OmniAuth (fora do plugin)
```

**O plugin declara o próprio `Gemfile`**, copiado cedo no Dockerfile. Ver 6.2.

Cada unidade tem um papel único: `Config` só lê configuração, `Provisioner` só
resolve identidade→usuário (testável sem HTTP e sem controller), o controller só
orquestra e delega o login ao core.

## 4. Fluxo

1. **Botão.** O hook `view_account_login_bottom` renderiza um
   `button_to POST /auth/google?back_url=…`, com token CSRF do Rails. O botão só
   aparece se `RedmineGoogleSso::Config.configured?`.
2. **Request phase.** O middleware OmniAuth redireciona ao Google com `state`,
   `nonce`, `scope=email profile` e `hd` (quando houver exatamente um domínio na
   allowlist).
3. **Callback.** `GET /auth/google/callback`. A strategy troca o code pelo token,
   valida o ID token e popula `request.env['omniauth.auth']`.
4. **`GoogleSsoController#callback`** decide nesta ordem, parando na primeira recusa:
   1. `email_verified` diferente de verdadeiro → recusa;
   2. domínio do e-mail fora da allowlist → recusa;
   3. `GoogleIdentity.find_by(subject: uid)` → usuário conhecido;
   4. senão, `User.find_by_mail(email)` ativo → cria o vínculo e segue;
   5. senão, se `auto_create` → provisiona usuário novo, já ativo;
   6. senão → recusa;
   7. usuário bloqueado ou pendente → `handle_inactive_user(user, signin_path)`;
   8. `user.twofa_active?` **e** `enforce_twofa` → `setup_twofa_session(user)` +
      `redirect_to account_twofa_confirm_path`; o core assume dali;
   9. senão → `successful_authentication(user)`.
5. **Falha.** `/auth/google/failure` e as recusas acima caem em `#failure`, que
   registra no log (com motivo e IP), põe `flash[:error]` e volta para `signin_path`.
   **A mensagem ao usuário não distingue "domínio negado" de "conta inexistente"** —
   evita virar oráculo de enumeração. O motivo real fica só no log.

### 4.1 Propagação de `back_url`

`successful_authentication` e `setup_twofa_session` leem `params[:back_url]`. O
callback não recebe os params originais, então o `back_url` viaja em
`request.env['omniauth.params']` (o OmniAuth preserva a query string da fase de
request) e o controller o copia para `params[:back_url]` antes de delegar.
A validação contra open redirect continua sendo a `validate_back_url` do core.

## 5. Modelo de dados

```ruby
create_table :google_identities do |t|
  t.integer  :user_id,       null: false
  t.string   :subject,       null: false   # a claim `sub` do Google
  t.string   :email                        # último e-mail visto, para auditoria
  t.datetime :created_on
  t.datetime :last_login_on
end
add_index :google_identities, :subject, unique: true
add_index :google_identities, :user_id
```

`GoogleIdentity belongs_to :user`. Ao apagar o usuário, apagar o vínculo.

**Por que não casar só por e-mail.** O `sub` é o identificador estável do Google; o
e-mail muda. Guardando o `sub`: (a) trocar o e-mail de alguém no Workspace não
quebra o vínculo; (b) ninguém herda uma conta Redmine por receber um endereço
reciclado. O casamento por e-mail acontece **uma vez**, na vinculação inicial.

### 5.1 Provisionamento

```
login       = e-mail completo   (o core aceita: /\A[a-z0-9_\-@.]*\z/i)
mail        = e-mail do Google
firstname   = given_name  (fallback: parte antes do @)
lastname    = family_name (fallback: '-', o core exige presença)
password    = User#random_password  (nunca usada; o usuário entra por SSO)
status      = ativo
language    = Setting.default_language
```

## 6. Configuração e deploy

### 6.1 O middleware

`config/application.rb` termina com:

```ruby
if File.exist?(File.join(File.dirname(__FILE__), 'additional_environment.rb'))
  instance_eval File.read(File.join(File.dirname(__FILE__), 'additional_environment.rb'))
end
```

É `instance_eval` **dentro do corpo da classe `Application`**, em tempo de config —
antes do `build_middleware_stack` do Rails. É onde o middleware entra, e é um arquivo
de configuração previsto pelo Redmine (existe `additional_environment.rb.example`),
não uma alteração do fonte do core.

```ruby
# config/additional_environment.rb
require 'omniauth'
require 'omniauth-google-oauth2'
require 'omniauth/rails_csrf_protection'

# Em after_initialize, não solto: este arquivo roda em tempo de config, quando
# Rails.logger ainda é nil. Atribuir nil zera o logger padrão do OmniAuth e a
# primeira falha de CSRF vira HTTP 500 em vez de recusa limpa.
config.after_initialize do
  OmniAuth.config.logger = Rails.logger
end

if ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
  config.middleware.use OmniAuth::Builder do
    provider :google_oauth2,
             ENV['GOOGLE_CLIENT_ID'],
             ENV['GOOGLE_CLIENT_SECRET'],
             name: 'google',
             scope: 'email,profile',
             prompt: 'select_account',
             access_type: 'online',
             setup: ->(env) {
               # `hd` é só dica de UI para o Google; a validação real é server-side.
               domains = RedmineGoogleSso::Config.allowed_domains
               env['omniauth.strategy'].options[:hd] = domains.first if domains.size == 1
             }
  end
end
```

O `if` é deliberado: sem credenciais, o middleware não é instalado e o boot não
quebra. O plugin detecta a ausência e esconde o botão.

**Duas gems, não uma.** O OmniAuth 2 exige POST na fase de request e valida CSRF via
`rack-protection`, que lê `session[:csrf]`; o Rails grava em `session[:_csrf_token]`.
`omniauth-rails_csrf_protection` substitui a `request_validation_phase` pela do
Rails. Sem ela, a validação nunca casa e todo login falha.

### 6.2 Docker

O `Dockerfile` copia `redmine-7/Gemfile` e roda `bundle install` **antes** de copiar
a árvore da aplicação — otimização de cache já documentada nos comentários dele. O
Gemfile do core faz glob em `plugins/*/Gemfile` (linha 133), mas nesse momento o
plugin ainda não existe na imagem.

Consequência: um `Gemfile` de plugin copiado só com a árvore não seria resolvido
no build, e em runtime o bundler acusaria alteração a cada `bundle exec`.

**Correção aplicada na implementação (revisa a decisão original deste spec).** O
repositório já resolvia isso para o plugin `motriz_2`, copiando só o Gemfile dele
antes do `bundle install`. O plugin de SSO segue o mesmo padrão, em vez de
introduzir um segundo: ele **traz o próprio `Gemfile`**, e o Dockerfile o copia
cedo. Isso também deixa o plugin instalável fora deste Docker sem instrução
extra, já que o Gemfile do core faz `eval_gemfile` em `plugins/*/Gemfile`.

```dockerfile
COPY plugins/redmine_google_sso/Gemfile $REDMINE_HOME/plugins/redmine_google_sso/Gemfile
```

Mais três mudanças de deploy:

1. `COPY plugins/redmine_google_sso/ $REDMINE_HOME/plugins/redmine_google_sso/`
   (depois do `COPY redmine-7/`);
2. escrever `config/additional_environment.rb` na imagem;
3. `REDMINE_PLUGINS_MIGRATE=1` no `compose.yaml` — o entrypoint já trata a variável.

### 6.3 Variáveis de ambiente

| Variável | Obrigatória | Uso |
|---|---|---|
| `GOOGLE_CLIENT_ID` | sim | OAuth client do Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | sim | idem |

Vão no `.env`, junto de `SECRET_KEY_BASE` e `POSTGRES_PASSWORD`. Não há fallback para
as settings do plugin: setting de plugin é serializada **em texto puro** na tabela
`settings`, e segredo não deve ficar assim.

Redirect URI a cadastrar no Google: `https://SEU_DOMINIO/auth/google/callback`.

### 6.4 Settings do plugin (tela de admin)

| Chave | Tipo | Default | Efeito |
|---|---|---|---|
| `allowed_domains` | texto, um por linha | vazio | Vazio = **nenhum login por SSO** (fail-closed) |
| `auto_create` | checkbox | ligado | Provisiona no primeiro login |
| `enforce_twofa` | checkbox | desligado | Exige o 2FA do Redmine mesmo após o Google |
| `button_label` | texto | "Entrar com Google" | Rótulo do botão |

Checkbox exige `hidden_field_tag` antes: o `SettingsController#plugin` grava o hash
inteiro, e campo ausente no POST some.

## 7. Segurança

| Risco | Defesa |
|---|---|
| CSRF na fase de request | POST + `omniauth-rails_csrf_protection` |
| CSRF / replay no callback | `state` do OmniAuth; `nonce` no ID token |
| E-mail não confirmado | recusa se `email_verified` não for verdadeiro |
| Conta fora da empresa | allowlist validada **no servidor**, fail-closed se vazia |
| Session fixation | `logged_user=` já faz `reset_session` |
| Open redirect | `validate_back_url` do core |
| Token em log | `config.filter_parameters += [:code, :id_token, :access_token, :refresh_token, :client_secret]` |
| Conta bloqueada entrando por SSO | `handle_inactive_user` antes de autenticar |
| Enumeração de contas | mensagem de erro única para todas as recusas |
| Rebaixar 2FA sem registro | quando `enforce_twofa` está desligado e o usuário tem 2FA ativo, registrar no log que foi pulado por SSO |

## 8. Testes

`OmniAuth.config.test_mode = true` com `mock_auth`, sem rede.

**Unitários** — `RedmineGoogleSso::Config` (parsing da allowlist, `configured?`),
`Provisioner` (casamento por `sub`, casamento por e-mail, criação, colisão de login),
`GoogleIdentity` (unicidade do `subject`).

**Funcionais** — usuário novo provisionado; usuário existente casado por e-mail;
`sub` já vinculado; `auto_create` desligado com usuário inexistente; domínio negado;
allowlist vazia; `email_verified` falso; usuário bloqueado; usuário pendente;
2FA ativo com `enforce_twofa` ligado; 2FA ativo com `enforce_twofa` desligado;
endpoint de falha; `back_url` preservado; `back_url` para host externo rejeitado;
botão ausente quando não configurado.

## 9. Fora de escopo

- Desvincular a conta pela tela do usuário (`/my/account`).
- Sincronizar grupos ou papéis do Google Workspace.
- Single logout (encerrar a sessão do Google junto com a do Redmine).
- Outros provedores OIDC além do Google.

## 10. Riscos e pontos a verificar na implementação

1. **Nomes de claim da strategy.** `email_verified` e `hd` vivem em
   `auth.extra.raw_info`, e o tipo de `email_verified` varia (booleano ou string)
   conforme o caminho usado pela gem. A implementação precisa **conferir contra a gem
   instalada** e normalizar, não confiar nesta especificação.
2. **Métodos privados do core.** `successful_authentication` e `setup_twofa_session`
   não são API pública. Fixar a faixa com `requires_redmine` e cobrir com testes.
3. **Ordem de carga.** `additional_environment.rb` roda antes de os plugins
   carregarem; o `setup` lambda é o que permite ler settings do banco, porque executa
   por requisição. Não tentar ler `Setting` em tempo de config.
4. **`login` derivado do e-mail** tem limite de 60 caracteres (`LOGIN_LENGTH_LIMIT`).
   Tratar o truncamento e a colisão resultante.
