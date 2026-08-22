# frozen_string_literal: true

module RedmineGoogleSso
  # Único ponto de leitura de configuração do plugin.
  #
  # Credenciais vêm exclusivamente do ambiente: setting de plugin é serializada
  # em texto puro na tabela `settings`, e segredo não deve ficar assim.
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
    # sem @ na frente. Sempre devolve em caixa baixa.
    def allowed_domains
      settings['allowed_domains'].to_s
                                 .split(/[\s,;]+/)
                                 .map {|d| d.strip.downcase.delete_prefix('@')}
                                 .reject(&:blank?)
                                 .uniq
    end

    # Compara o domínio inteiro, nunca por sufixo: com 'motriz.com.br' na lista,
    # 'evilmotriz.com.br' precisa continuar sendo recusado.
    def domain_allowed?(email)
      email = email.to_s
      return false unless email.include?('@')

      domain = email.downcase.split('@').last
      return false if domain.blank?

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

    # Fail-closed: sem credenciais OU sem nenhum domínio liberado, o SSO não
    # existe. Instalar o plugin sem configurar não pode abrir o Redmine.
    def configured?
      credentials? && allowed_domains.any?
    end
  end
end
