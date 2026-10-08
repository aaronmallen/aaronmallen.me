# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class SuggestionsBanner < Component
          prop :count, Blog::Types::Integer

          def view_template
            div(class: "post-banner") do
              Icon("fa-solid fa-robot")
              span(class: "post-banner-text") { t(".count", count: @count) }
              Button(
                small: true, command: "show-modal", commandfor: Suggestions::ID,
                data: { dialog_open: Suggestions::ID },
              ) { t(".review") }
            end
          end
        end
      end
    end
  end
end
