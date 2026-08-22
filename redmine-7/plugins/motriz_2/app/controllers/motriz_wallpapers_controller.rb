# frozen_string_literal: true

# Envio, exclusão e entrega dos papéis de parede da tela de login.
#
# `show` é a única ação pública, e é pública por necessidade: o fundo da tela
# de login precisa carregar antes de existir sessão. Todo o saneamento de nome
# e a checagem de diretório vivem em RedmineAsapTheme::Wallpapers.
class MotrizWallpapersController < ApplicationController
  skip_before_action :check_if_login_required, :check_password_change, only: [:show]
  before_action :require_admin, except: [:show]

  # A tela de configuração do plugin é um único form_tag do Redmine. Estes
  # endpoints são alcançados de dentro dele por botões com `formaction`, que
  # trazem junto os campos de configuração — ignorados aqui de propósito.
  def show
    caminho = RedmineAsapTheme::Wallpapers.caminho_enviado(params[:nome])
    return render_404 unless caminho

    send_file caminho,
              type: RedmineAsapTheme::Wallpapers.tipo_de(caminho),
              disposition: 'inline'
  end

  def create
    identificador, erro = RedmineAsapTheme::Wallpapers.gravar(params[:wallpaper_file])

    if erro
      flash[:error] = l(erro)
    else
      flash[:notice] = l(:motriz_wallpaper_enviado)
      # Recém-enviado já entra em uso: é o que o administrador acabou de
      # escolher ao enviar, e evita uma segunda ida à tela para selecioná-lo.
      Setting.plugin_motriz_2 = Setting.plugin_motriz_2.merge(
        RedmineAsapTheme::Wallpapers::CHAVE_SELECAO => identificador
      )
    end

    voltar
  end

  def destroy
    if RedmineAsapTheme::Wallpapers.excluir(params[:identificador])
      flash[:notice] = l(:motriz_wallpaper_excluido)
    else
      flash[:error] = l(:motriz_wallpaper_erro_excluir)
    end

    voltar
  end

  def restore
    RedmineAsapTheme::Wallpapers.restaurar_embutidos
    flash[:notice] = l(:motriz_wallpaper_restaurado)
    voltar
  end

  private

  def voltar
    redirect_to plugin_settings_path(:motriz_2, tab: 'asap_theme_login')
  end
end
