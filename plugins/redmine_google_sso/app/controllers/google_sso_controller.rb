# frozen_string_literal: true

# Recebe o callback do Google e delega o login ao core.
#
# Herda de AccountController para reaproveitar o caminho de autenticação já
# testado do Redmine:
#
#   * `skip_before_action :check_if_login_required` — sem isso, com
#     Setting.login_required ligado, o callback entraria em loop de redirect;
#   * `successful_authentication` — faz reset_session (proteção contra session
#     fixation), dispara o hook controller_account_success_authentication_after
#     e respeita back_url com validação contra open redirect;
#   * `setup_twofa_session` — grava o Token que o `twofa_setup` do core lê, o
#     que devolve o fluxo de 2FA inteiro ao core, sem reimplementar tela nem
#     contador de tentativas;
#   * `handle_inactive_user` — trata bloqueado e pendente como no login por senha.
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
                    '(enforce_twofa desligado)'
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

  # O callback não recebe os params originais do botão — quem falou com o
  # navegador foi o middleware. O OmniAuth preserva a query string da fase de
  # request em omniauth.params; copiamos de volta para params porque é de lá
  # que successful_authentication e setup_twofa_session leem o back_url.
  # A validação contra open redirect continua sendo a validate_back_url do core.
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
  # inexistente" transformaria a tela de login num oráculo de enumeração de
  # contas. O motivo real fica só no log.
  def recusar(motivo)
    logger.warn "SSO Google recusado (#{motivo}) de #{request.remote_ip} em #{Time.now.utc}"
    flash[:error] = l(:notice_google_sso_denied)
    redirect_to signin_path
  end
end
