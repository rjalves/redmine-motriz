require_dependency "avatars_helper"

module RedmineAsapTheme
    module ApplicationAvatarPatch
        def self.included(base)
            base.class_eval do
                alias_method :avatar_without_local, :avatar
                alias_method :avatar, :avatar_with_local
            end
        end

        def avatar_with_local(user, options = { })
            if user.is_a?(User)then
                av = user.attachments.find_by_description 'avatar'
                options[:size] = "32" unless options[:size]
                if av then
                    # image_url = url_for :only_path => true, :controller => 'account', :action => 'get_avatar', :id => user
                    image_url = url_for(only_path: true, controller: 'account', action: 'get_avatar', id: user, format: 'png')
                    options[:size] = "32" unless options[:size]
                    return "<img class=\"gravatar #{options[:class]}\" width=\"#{options[:size]}\" height=\"#{options[:size]}\" src=\"#{image_url}\" title=\"#{options[:title]}\"/>".html_safe
                else
                    # return "<img class=\"gravatar\" width=\"#{options[:size]}\" height=\"#{options[:size]}\"  title=\"#{options[:title]}\" avatar=\"#{ user.name[0..1].upcase }\" />".html_safe
                    #
                    # letter_avatar_tag ESCREVE em disco: o gem gera o PNG sob
                    # public/system/letter_avatars/<versao>/<iniciais>/ na
                    # primeira vez que aquelas iniciais aparecem. Se essa
                    # escrita falhar, a exceção sobe pelo layout e derruba a
                    # página INTEIRA — não o avatar, a página. Como este helper
                    # é chamado no base.html.erb, isso significa erro 500 em
                    # todo o Redmine, para todo mundo.
                    #
                    # Aconteceu em produção: um processo root criou o diretório
                    # de cache, o Puma roda como `redmine` e passou a tomar
                    # Errno::EACCES em cada requisição. O login por Google
                    # funcionava; o que quebrava era a home logo depois.
                    #
                    # Cache é acessório. Falhou, cai para o avatar do core
                    # (gravatar ou iniciais em CSS), que não toca em disco.
                    begin
                        return letter_avatar_tag(user.name, options[:size].to_i, class: 'gravatar user-avatar')
                    rescue SystemCallError, IOError => e
                        Rails.logger.error(
                            "[motriz_2] cache de letter avatar indisponível (#{e.class}: #{e.message}); " \
                            'usando o avatar padrão do Redmine'
                        )
                    end
                end
            end
            avatar_without_local(user, options)
        end
    end
end
AvatarsHelper.include RedmineAsapTheme::ApplicationAvatarPatch
