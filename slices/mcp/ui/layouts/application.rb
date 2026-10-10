# frozen_string_literal: true

module MCP
  module UI
    module Layouts
      class Application < Blog::UI::Layouts::Application
        def view_template(&)
          document { body { main(id: "main", class: "adm-main", &) } }
        end

        private

        def page_title = t(".title", owner: Hanami.app.settings.owner_name)

        def render_head
          super
          meta(name: "robots", content: BrowserAction::ROBOTS)
        end
      end
    end
  end
end
