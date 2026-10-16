# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Webmentions
        class Settings < View
          include Components::Webmentions

          LIVE_TABLES = %w[posts trusted_authors webmention_settings].freeze

          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :settings, Blog::Types::Instance(ROM::Struct)
          prop :trusted, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(title: t(".heading"))
            div(class: "g-main") do
              div(class: "stack") do
                SettingsCard(settings: @settings)
                TrustedAuthorsCard(authors: @trusted)
              end
              PostsCard(posts: @posts)
            end
          end
        end
      end
    end
  end
end
