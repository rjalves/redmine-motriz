# Instalação do middleware OmniAuth para o plugin redmine_google_sso.
#
# Este arquivo é lido pela última linha de config/application.rb com
# instance_eval DENTRO do corpo da classe Application — ou seja, em tempo de
# config, antes do build_middleware_stack do Rails. É o único lugar de onde dá
# para instalar middleware Rack por aqui: o init.rb de um plugin roda dentro de
# to_prepare, quando a pilha de middleware já foi construída.

require 'omniauth'
require 'omniauth-google-oauth2'
require 'omniauth/rails_csrf_protection'

# Em after_initialize, não aqui fora: este arquivo roda em tempo de config, e
# nesse momento Rails.logger ainda é nil. Atribuir nil aqui zeraria o logger
# padrão do OmniAuth, e a primeira falha de CSRF morreria com
# "undefined method 'debug' for nil" — HTTP 500 em vez de recusa limpa.
config.after_initialize do
  OmniAuth.config.logger = Rails.logger
end

# Sem credenciais o middleware simplesmente não é instalado e o boot segue
# normalmente; o plugin detecta a ausência e esconde o botão. Derrubar o Redmine
# inteiro porque falta uma variável de ambiente seria pior do que não ter SSO.
if ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
  config.middleware.use OmniAuth::Builder do
    provider(
      :google_oauth2,
      ENV['GOOGLE_CLIENT_ID'],
      ENV['GOOGLE_CLIENT_SECRET'],
      name: 'google',
      scope: 'email,profile',
      prompt: 'select_account',
      access_type: 'online',
      setup: lambda do |env|
        # `hd` é dica de interface para o Google, não garantia: ele apenas
        # sugere a conta de trabalho na tela de escolha. A validação de domínio
        # que vale é a do Provisioner, no servidor.
        dominios = RedmineGoogleSso::Config.allowed_domains
        env['omniauth.strategy'].options[:hd] = dominios.first if dominios.size == 1
      end
    )
  end
end

config.filter_parameters += [:code, :id_token, :access_token, :refresh_token, :client_secret]
