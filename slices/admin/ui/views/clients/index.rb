# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Clients
        class Index < View
          LIVE_TABLES = %w[oauth_clients oauth_tokens].freeze

          prop :clients, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(title: t(".heading"))
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
