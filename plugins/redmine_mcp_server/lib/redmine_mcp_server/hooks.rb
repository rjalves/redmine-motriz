# frozen_string_literal: true

module RedmineMcpServer
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_my_account, partial: 'hooks/mcp_account_block'

    def view_layouts_base_html_head(context = {})
      return '' unless Config.enabled?

      stylesheet_link_tag('mcp_server', plugin: 'redmine_mcp_server')
    end
  end
end
