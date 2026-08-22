# frozen_string_literal: true

module RedmineGoogleSso
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_account_login_bottom, partial: 'hooks/google_sso_login_button'

    def view_layouts_base_html_head(context = {})
      return '' unless Config.configured?

      stylesheet_link_tag('google_sso', plugin: 'redmine_google_sso')
    end
  end
end
