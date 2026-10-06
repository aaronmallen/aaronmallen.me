# frozen_string_literal: true

module Admin
  module UI
    module Layouts
      class Application < Blog::UI::Layouts::Application
        include Components
        include Components::Nav

        def view_template(&)
          doctype

          html(lang: "en", data: { site_theme: saved_theme }) do
            head { render_head }
            body(class: "adm") { render_body(&) }
          end
        end

        private

        def build_navigation = slice["operations.build_navigation"].call(current_path: request.path)

        def render_body(&)
          session = Auth::Session.for(request)
          navigation = build_navigation if session.signed_in?

          MainNav(session:)
          ContextBar(current: navigation.current, alert: navigation.alert?) if navigation
          main(id: "main", class: "adm-main", data: { live: (path(:admin_events) if navigation) }, &)
          Toast(message: toast_message) if toast_message
          navigation ? render_signed_in_tail(navigation) : Footer()
        end

        def render_head
          super
          meta(name: "robots", content: Slice::ROBOTS)
          script(src: asset_url("admin/app.js"), type: "module")
        end

        def render_palette(navigation)
          Palette(sections: navigation.sections, actions: navigation.actions)
          Components::Tasks::CreateDialog(today: Blog::TimeZone.today, origin: content_for(:task_origin))
          Components::Tasks::Panel()
          SlashButton()
          KeyHelp()
        end

        def render_signed_in_tail(navigation)
          ConfirmDialog()
          Footer()
          render_palette(navigation)
        end

        def title_suffix = t(".title", owner: Blog::Owner.full_name)

        def toast_message = flash[Components::Toast::FLASH_KEY]
      end
    end
  end
end
