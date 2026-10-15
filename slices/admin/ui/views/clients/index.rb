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
            Card(title: t(".connected"), data: { key_list: true }) do |card|
              card.side { span(class: "settings-count") { t(".count", count: @clients.size) } }
              next Empty { t(".empty") } if @clients.empty?

              @clients.each { ClientRow(client: it) }
            end
          end
        end
      end
    end
  end
end
