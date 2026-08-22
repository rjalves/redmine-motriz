# Redmine Google SSO

Login no Redmine 7 com conta Google corporativa, com allowlist de domínio.
O login por senha continua funcionando lado a lado.

## O que faz

- Botão "Entrar com Google" na tela de login, ao lado do formulário de senha.
- Só aceita e-mail **verificado** e de **domínio na allowlist**.
- Cria o usuário no primeiro acesso (configurável), já ativo.
- Guarda o `sub` do Google, então trocar o e-mail de alguém no Workspace não
  quebra o vínculo.
- Respeita usuário bloqueado e pendente, como o login por senha.
- Opcionalmente exige também o 2FA do Redmine depois do Google.

## Requisitos

- Redmine **7.0.0** ou maior
- Gems `omniauth-google-oauth2` e `omniauth-rails_csrf_protection`

> A segunda gem não é opcional. O OmniAuth 2 valida CSRF via `rack-protection`,
> que procura o token em `session[:csrf]`; o Rails grava em
> `session[:_csrf_token]`. Sem ela, **todo login falha**.

## Instalação

### 1. Gems

O plugin traz o próprio `Gemfile`, e o Gemfile do core faz `eval_gemfile` em
`plugins/*/Gemfile`. Numa instalação comum, basta:

```bash
bundle install
```

**Num build Docker, atenção à ordem das camadas.** Se o `bundle install` roda
antes de a árvore da aplicação ser copiada (padrão para preservar o cache das
gems nativas), o glob não encontra o plugin no build, e em runtime o bundler
acusa "Gemfile alterado" a cada `bundle exec`. A correção é copiar só o Gemfile
do plugin antes do `bundle install`:

```dockerfile
COPY plugins/redmine_google_sso/Gemfile $REDMINE_HOME/plugins/redmine_google_sso/Gemfile
# ... database.yml, Gemfile.local ...
RUN bundle install
COPY plugins/redmine_google_sso/ $REDMINE_HOME/plugins/redmine_google_sso/
```

### 2. Plugin

```bash
cp -r redmine_google_sso /caminho/do/redmine/plugins/
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

### 3. Middleware

Copie o `config/additional_environment.rb` **deste plugin** para o `config/` do
Redmine:

```bash
cp plugins/redmine_google_sso/config/additional_environment.rb config/
```

Ele mora dentro do plugin porque o `.gitignore` do Redmine ignora
`/config/additional_environment.rb`; versioná-lo lá significaria perdê-lo num
clone limpo. Se você já tiver um `additional_environment.rb` com outras
configurações, **junte** os conteúdos em vez de sobrescrever. Ele é lido pela última linha de `config/application.rb`
com `instance_eval` dentro do corpo da classe `Application` — em tempo de
config, antes do `build_middleware_stack`. É o único ponto de onde dá para
instalar middleware Rack sem alterar o fonte do core: o `init.rb` de um plugin
roda em `to_prepare`, quando a pilha já foi construída.

### 4. Credenciais

No Google Cloud Console, crie um OAuth client do tipo "Aplicativo da Web" e
cadastre o redirect URI:

```
https://SEU_DOMINIO/auth/google/callback
```

Exporte as duas variáveis no ambiente do Redmine:

```bash
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
```

**Só por ambiente.** Não há campo na tela de admin porque setting de plugin é
serializada em texto puro na tabela `settings`.

Faltando qualquer uma das duas, o middleware não é instalado, o botão não
aparece e o Redmine sobe normalmente.

### 5. Configurar

**Administração → Plugins → Redmine Google SSO → Configurar**

| Campo | Efeito |
|---|---|
| Domínios permitidos | Um por linha. **Vazio bloqueia todo login por Google.** |
| Criar usuário no primeiro acesso | Desligado, só entra quem já tem conta |
| Exigir o 2FA do Redmine também | Ligado, quem tem 2FA passa pelo código depois do Google |
| Rótulo do botão | Texto do botão; vazio usa a tradução |

Reinicie o Redmine.

## Como funciona

```
[Entrar com Google]  --POST-->  /auth/google        (middleware OmniAuth)
                                      |
                                      v
                            Google (state, nonce, hd)
                                      |
                                      v
        /auth/google/callback  -->  GoogleSsoController#callback
                                      |
             e-mail verificado? domínio na lista? sub conhecido?
                                      |
                     AccountController#successful_authentication
```

`GoogleSsoController` herda de `AccountController` para reaproveitar o caminho
de login já testado do core: `reset_session`, hook de autenticação, validação de
`back_url` e o fluxo de 2FA inteiro.

## Segurança

| Risco | Defesa |
|---|---|
| CSRF na fase de request | POST + `omniauth-rails_csrf_protection` |
| CSRF/replay no callback | `state` do OmniAuth, `nonce` no ID token |
| E-mail não confirmado | recusa se `email_verified` não for verdadeiro |
| Conta de fora | allowlist validada no servidor, fail-closed |
| Session fixation | `reset_session` do core |
| Open redirect | `validate_back_url` do core |
| Enumeração de contas | mensagem de erro única; motivo só no log |

O parâmetro `hd` enviado ao Google é apenas dica de interface. A validação que
vale é a do servidor.

## Testes

```bash
docker build -f docker/Dockerfile.test -t redmine-motriz:sso-test .
docker run --rm redmine-motriz:sso-test
```

A imagem de teste instala todos os grupos do bundle (produção exclui
`development:test`, e sem `mocha`/`simplecov` o `test_helper` do Redmine nem
carrega), usa SQLite e isola este plugin dos demais.

## Fora de escopo

- Desvincular a conta pela tela do usuário
- Sincronizar grupos ou papéis do Workspace
- Single logout
- Outros provedores OIDC
