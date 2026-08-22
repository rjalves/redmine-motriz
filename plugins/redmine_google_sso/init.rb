Redmine::Plugin.register :redmine_google_sso do
  name        'Redmine Google SSO'
  author      'Roberto Alves'
  description 'Login com conta Google corporativa, com allowlist de domínio'
  version     '0.1.0'
  url         'https://github.com/rjalves/redmine_google_sso'
  requires_redmine version_or_higher: '7.0.0'

  settings default: {
             'allowed_domains' => '',
             'auto_create'     => '1',
             'enforce_twofa'   => '0',
             'button_label'    => ''
           },
           partial: 'settings/redmine_google_sso_settings'
end

# Referenciar a constante basta: o Zeitwerk carrega lib/redmine_google_sso/hooks.rb
# e o `inherited` de Redmine::Hook::Listener registra o listener. Nada de
# `require` aqui — o lib/ do plugin é autoloadado, e requerer à mão duplicaria a
# constante a cada reload em desenvolvimento.
RedmineGoogleSso::Hooks
