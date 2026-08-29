# frozen_string_literal: true

module MCP
  module UI
    module Layouts
      class Application < Blog::UI::Layouts::Application
        def view_template(&)
          doctype

          html(lang: "en", data: { site_theme: saved_theme }) do
            head { render_head }
            body { main(id: "main", class: "adm-main", &) }
          end
        end

        private

        def page_title = t(".title", owner: Blog::Owner.full_name)

        def render_head
          super
          meta(name: "robots", content: BrowserAction::ROBOTS)
        end
      end
    end
  end
end
