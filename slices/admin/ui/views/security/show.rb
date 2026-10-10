# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Security
        class Show < View
          include Components::Security

          ROWS = Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          prop :clients, ROWS
          prop :honeybadger_url, Blog::Types::String.optional
          prop :sightings, ROWS
          prop :sign_ins, ROWS
          prop :tokens, ROWS

          def view_template
            SettingsHead(title: t(".heading")) { honeybadger_link if @honeybadger_url }
            p(class: "settings-aside") { t(".sub") }
            div(class: "g-main even") do
              sign_ins
              Card(title: t(".credentials")) { credentials }
            end
          end

          private

          def client_name(client) = client.client_name.to_s.strip.then { it.empty? ? client.client_id : it }

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
            @clients.each { credential(t(".client"), client_name(it), sighted[[nil, it.id]]) }
          end

          def honeybadger_link
            Button(
              href: @honeybadger_url, **Blog::UI::Component::OUTBOUND, icon: "fa-solid fa-bug",
            ) { t(".honeybadger") }
          end

          def sighted = @sighted ||= @sightings.group_by { [it.api_token_id, it.oauth_client_id] }

          def sign_ins
            Card(title: t(".sign_ins")) do
              next Empty { t(".no_sign_ins") } if @sign_ins.empty?

              @sign_ins.each { SignInRow(sign_in: it) }
            end
          end
        end
      end
    end
  end
end
