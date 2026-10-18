# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Security
        class Show < View
          include Components::Security

          LIVE_TABLES = %w[oauth_clients oauth_tokens sign_ins].freeze
          ROWS = Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          prop :clients, ROWS
          prop :honeybadger_url, Blog::Types::String.optional
          prop :sightings, ROWS
          prop :sign_ins, Blog::Types::Instance(Blog::Structs::Paged)
          prop :tabs, Blog::Types::Hash
          prop :tokens, ROWS

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(tab: :security, title: t(".heading"), counts: @tabs) { honeybadger_link if @honeybadger_url }
            p(class: "settings-aside") { t(".sub") }
            div(class: "g-main even") do
              sign_ins
              Card(title: t(".credentials")) { credentials }
            end
          end

          private

          def credential(kind, name, sightings)
            div(class: "security-cred") do
              p(class: "security-cred-name") do
                plain name
                whitespace
                span(class: "security-cred-kind") { kind }
              end
              next Empty { t(".no_sightings") } if sightings.nil?

              sightings.each { SightingRow(sighting: it) }
            end
          end

          def credentials
            return Empty { t(".no_credentials") } if @tokens.empty? && @clients.empty?

            @tokens.each { credential(t(".token"), it.name, sighted[[it.id, nil]]) }
            @clients.each { credential(t(".client"), it.display_name, sighted[[nil, it.id]]) }
          end

          def honeybadger_link
            Button(
              href: @honeybadger_url, **Blog::UI::Component::OUTBOUND, icon: "fa-solid fa-bug",
            ) { t(".honeybadger") }
          end

          def sighted = @sighted ||= @sightings.group_by { [it.api_token_id, it.oauth_client_id] }

          def sign_ins
            Card(title: t(".sign_ins"), empty: (t(".no_sign_ins") if @sign_ins.rows.empty?)) do
              @sign_ins.rows.each { SignInRow(sign_in: it) }
              Pager(page: @sign_ins, route: :admin_security)
            end
          end
        end
      end
    end
  end
end
