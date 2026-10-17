# frozen_string_literal: true

module Admin
  module UI
    module Layouts
      class Application < Blog::UI::Layouts::Application
        include Components
        include Components::Nav
        include Navigated

        DRAWER_HEADER = "HTTP_X_DRAWER"
        LIVE_TABLES = %w[
          mail_accounts mail_labels mail_messages mail_settings mail_thread_labels mail_thread_tags mail_threads people
          tags task_sources tasks webmentions
        ].freeze

        def view_template(&)
          return drawn(&) if request.get_header(DRAWER_HEADER)

          document do
            body(class: "adm") { render_body(&) }
          end
        end

        private

        def drawn
          yield
          Toast(message: toast_message) if toast_message
        end

        def journal_dialog
          written = content_for(:journal_write)
          return raw(safe(written)) if written

          Components::Journal::WriteDialog(today: Blog::TimeZone.today, return_to: (request.fullpath if request.get?))
        end

        def live_tables
          listed = content_for(:live_tables)
          (LIVE_TABLES | listed).join(" ") if listed
        end

        def main_data
          {
            live: (path(:admin_events) if navigation),
            live_at: request.env[Live::Clock::KEY],
            live_tables:,
            morph_failed: t(".morph_failed"),
          }
        end

        def render_body(&)
          session = Auth::Session.for(request)
          navigation ? TopBar(navigation:) : MainNav(session:)
          main(id: "main", class: "adm-main", data: main_data, &)
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
          journal_dialog
          KeyHelp()
        end

        def render_signed_in_tail(navigation)
          Confirm()
          Footer()
          render_palette(navigation)
        end

        def stylesheet = "admin/app.css"

        def title_suffix = t(".title", owner: settings.owner_name)

        def toast_message = flash[Components::Toast::FLASH_KEY]
      end
    end
  end
end
