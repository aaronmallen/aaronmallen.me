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
              @clients.each { ClientRow(client: it) }
            end
          end

          private

          def list_props
            { note: t(".count", count: @clients.size), note_class: "settings-count",
              empty: (t(".empty") if @clients.empty?) }
          end
        end
      end
    end
  end
end
