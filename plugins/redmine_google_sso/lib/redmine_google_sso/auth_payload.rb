# frozen_string_literal: true

module RedmineGoogleSso
  # Fronteira com a gem OmniAuth.
  #
  # Todo o resto do plugin fala este Struct, nunca o AuthHash do OmniAuth. Isso
  # deixa o Provisioner testável sem a gem instalada e concentra num único
  # método o risco de os nomes de claim mudarem entre versões da strategy.
  AuthPayload = Struct.new(:subject, :email, :email_verified, :first_name, :last_name,
                           keyword_init: true) do
    # `email_verified` chega como true, "true" ou 1 conforme o caminho usado
    # pela strategy (id_token decodificado x endpoint userinfo). Qualquer outra
    # coisa — inclusive nil — conta como não verificado.
    def email_verified?
      %w[true 1].include?(email_verified.to_s.downcase)
    end

    def self.from_omniauth(auth)
      info = auth['info'] || {}
      raw  = auth.dig('extra', 'raw_info') || {}

      new(
        subject:        presence_of(auth['uid']),
        email:          presence_of(info['email'] || raw['email']),
        email_verified: raw.key?('email_verified') ? raw['email_verified'] : info['email_verified'],
        first_name:     presence_of(info['first_name'] || raw['given_name']),
        last_name:      presence_of(info['last_name'] || raw['family_name'])
      )
    end

    def self.presence_of(value)
      value.to_s.strip.presence
    end
    private_class_method :presence_of
  end
end
