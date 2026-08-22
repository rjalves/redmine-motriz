# frozen_string_literal: true

require_dependency 'application_helper'

module RedmineAsapTheme
  # Helper de view dos papéis de parede.
  #
  # Entra por patch no ApplicationHelper porque o Redmine roda com
  # `include_all_helpers = false` (config/application.rb): app/helpers de plugin
  # não é varrido, e patch é como o resto deste plugin já expõe helper de view.
  module WallpapersHelperPatch
    # Resolve as duas origens: enviado sai pelo controller, porque vive em
    # files/ e está fora do pipeline de assets; embutido sai pelo Propshaft,
    # que acrescenta o digest.
    def motriz_wallpaper_src(identificador)
      return nil if identificador.blank?

      w = RedmineAsapTheme::Wallpapers
      if w.enviado?(identificador)
        motriz_wallpaper_path(nome: w.nome_de(identificador))
      else
        nome = w.nome_seguro(identificador)
        nome ? asset_path("plugin_assets/motriz_2/login/#{nome}") : nil
      end
    end
  end
end

Rails.application.config.after_initialize do
  ApplicationHelper.prepend RedmineAsapTheme::WallpapersHelperPatch
end
