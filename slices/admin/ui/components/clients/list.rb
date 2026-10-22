# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Clients
        class List < Component
          LIVE_TABLES = %w[oauth_clients oauth_tokens].freeze

          prop :clients, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".connected"), **list_props, data: { key_list: true }) do
              calling.each { group(it) }
              idle_list
            end
          end

          private

          def apps = @clients.group_by { [it.display_name, it.redirect_host] }.values

          def called_recently?(clients)
            since = Time.now - (60 * 60)
            clients.any? { it.last_used_at&.>=(since) }
          end

          def calling = groups.fetch(true, Blog::Constants::EMPTY_ARRAY)

          def group(clients)
            return ClientRow(client: clients.first) if clients.one?

            details(class: "today-more") do
              summary do
                Icon("fa-solid fa-chevron-right today-more-chev")
                plain group_title(clients.first, clients.size)
              end
              clients.each { ClientRow(client: it) }
            end
          end

          def group_title(client, count)
            host = client.redirect_host.then { it unless it == client.display_name }
            dotted(client.display_name, host, t(".registrations", count:))
          end

          def groups = @groups ||= apps.group_by { called_recently?(it) }

          def idle = groups.fetch(false, Blog::Constants::EMPTY_ARRAY)

          def idle_list
            return if idle.empty?

            p(class: "svc-group-label") { t(".idle") }
            idle.each { group(it) }
          end

          def list_props
            return { note: t(".nothing"), note_class: "settings-count", empty: t(".empty") } if @clients.empty?

            { note: t(".count", count: calling.size), note_class: "settings-count" }
          end
        end
      end
    end
  end
end
