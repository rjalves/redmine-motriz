require 'redmine'

Redmine::Plugin.register :motriz_2 do
  name 'Motriz 2'
  author 'Motriz Digital — sobre Redmine ASAP Theme (DGAC/DSNA - Tantic)'
  description 'Identidade Motriz sobre a estrutura do Redmine ASAP Theme (Tailwind CSS + Stimulus/Turbo)'
  version '2.4.0-motriz.1'
  url 'https://github.com/tantic/redmine_asap_theme'
  author_url 'https://github.com/tantic'
  requires_redmine version_or_higher: '6.0.0'

  # O upstream nasce com os ajustes vazios, o que deixa o slot do logotipo sem
  # fundo até alguém configurar. Aqui já vêm preenchidos com o verde escuro
  # institucional, que é o único fundo colorido que o brandbook admite para o
  # logotipo. Gerados por tools/build_tailwind_theme.py.
  settings :default => {
             'redmine_asap_colors_logo_bg' => '#024b40',
             'redmine_asap_colors_logo_bg_hover' => '#1f5f53',
             'redmine_asap_login_wallpaper' => 'fond1.jpg'
           },
           :partial => 'settings/motriz_2/settings'
  delete_menu_item :project_menu, :settings

  menu :tools_menu,
        :label_my_page,
        { :controller => 'my', :action => 'page' },
        :caption => :label_my_page,
        plugin: 'motriz_2',
        html: { class: 'icon' },
        icon: 'my-page'
end


lib_dir = File.join(File.dirname(__FILE__), 'lib', 'redmine_asap_theme')

# Redmine patches
patch_path = File.join(lib_dir, '*_patch.rb')
Dir.glob(patch_path).each do |file|
  basename = File.basename(file)
  next if basename.start_with?('easy_gantt') && !Redmine::Plugin.installed?(:easy_gantt)
  next if basename.start_with?('easy_wbs') && !Redmine::Plugin.installed?(:easy_wbs)
  require file
end

rat_helpers = File.join(lib_dir, 'helpers.rb')
require rat_helpers



libraries =
  [
    'hooks',
    'notification_listener',
  ]
libraries.each do |library|
  require_dependency File.expand_path(library, lib_dir)
end

# O upstream faz `require lib_dir` cru, apontando para lib/redmine_asap_theme.rb —
# arquivo que não existe no repositório. `require` de diretório levanta LoadError
# e derruba o boot do Redmine. Guardado até o upstream resolver.
require lib_dir if File.exist?("#{lib_dir}.rb")

# Load Deface overrides at boot time so Deface can pick them up via _early/early_check
# (Redmine plugins are not Rails Engines, so Deface doesn't scan them automatically)
overrides_path = File.join(File.dirname(__FILE__), 'app', 'overrides', '**', '*.rb')
Dir.glob(overrides_path).each { |f| require f }

include LetterAvatar::AvatarHelper
LetterAvatar.setup do |config|
  # config.fill_color        = 'rgba(255, 255, 255, 1)' # default is 'rgba(255, 255, 255, 0.65)'
  config.cache_base_path   = 'public/system'     # default is 'public/system'
  config.colors_palette    = :google                # default is :google, :iwanthue
  config.weight            = 100                      # default is 300
  config.annotate_position = '-0+5'                  # default is -0+5
  config.letters_count     = 2                        # default is 1
  config.pointsize         = 300                       # default is 140
end


Rails.configuration.to_prepare do
  require_dependency 'issues_helper'
  IssuesHelper.prepend RedmineAsapTheme::IssuesHelperPatch
end

if Redmine::Plugin.installed?(:easy_wbs)
  begin
    EasyWbsController.include SortHelper
    EasyWbsController.prepend RedmineAsapTheme::EasyWbsControllerPatch
  rescue NameError => e
    Rails.logger.warn "[motriz_2] EasyWbs patch skipped: #{e.message}"
  end
end
