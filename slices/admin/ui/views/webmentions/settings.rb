# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Webmentions
        class Settings < View
          include Components::Webmentions

          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :settings, Blog::Types::Instance(ROM::Struct)

          def view_template
            SettingsHead(title: t(".heading"))
            div(class: "g-main") do
              SettingsCard(settings: @settings)
              PostsCard(posts: @posts)
            end
          end
        end
      end
    end
  end
end
