# frozen_string_literal: true

# Vínculo entre um usuário do Redmine e uma identidade do Google.
#
# Guardamos o `sub` do Google, não o e-mail, porque o `sub` é o identificador
# estável: trocar o e-mail de alguém no Workspace não quebra o vínculo, e
# ninguém herda uma conta do Redmine ao receber um endereço reciclado. O
# casamento por e-mail acontece uma única vez, na vinculação inicial.
class GoogleIdentity < ApplicationRecord
  belongs_to :user

  validates :subject, presence: true, uniqueness: true
  validates :user_id, presence: true

  def record_login!(email)
    update_columns(email: email, last_login_on: Time.current)
  end
end
