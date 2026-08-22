# frozen_string_literal: true

module RedmineGoogleSso
  # Resolve um AuthPayload para um User do Redmine, criando o vínculo e, quando
  # permitido, o próprio usuário.
  #
  # Não decide nada sobre sessão, 2FA ou redirecionamento: isso é do controller.
  # Também não conhece OmniAuth — recebe um AuthPayload já normalizado.
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
      raise Error, :no_email         if @payload.subject.blank? || @payload.email.blank?
      raise Error, :email_unverified unless @payload.email_verified?
      raise Error, :domain_denied    unless Config.domain_allowed?(@payload.email)
    end

    # Sem escopo `.active` de propósito. Se existir um usuário bloqueado com
    # este e-mail, queremos encontrá-lo e deixar o controller recusar o acesso,
    # em vez de criar um segundo usuário para a mesma pessoa.
    def usuario_existente
      User.find_by_mail(@payload.email)
    end

    def provisionar
      return nil unless Config.auto_create?

      usuario = User.new(
        login:     login_disponivel,
        mail:      @payload.email,
        firstname: @payload.first_name.presence || @payload.email.split('@').first,
        lastname:  @payload.last_name.presence || '-',
        language:  Setting.default_language
      )
      usuario.random_password
      usuario.activate
      usuario.save!
      usuario
    end

    # O core limita o login a LOGIN_LENGTH_LIMIT caracteres, e e-mail corporativo
    # passa disso com facilidade. Trunca e, se o truncamento colidir com alguém,
    # acrescenta um sufixo numérico ainda dentro do limite.
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
