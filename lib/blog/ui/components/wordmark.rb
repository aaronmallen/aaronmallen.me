# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Wordmark < Component
        SLASH = "/"
        SPLIT = " "

        prop :placement, Blog::Types::String

        def view_template
          href = path(:root)
          owner = Hanami.app.settings.owner_name

          a(class: ["wordmark", @placement], href:, aria: { label: t(".label", owner:), current: current(href) }) do
            name(owner)
          end
        end

        private

        def current(href) = ("page" if request.path == href)

        def name(owner)
          first, rest = owner.split(SPLIT, 2)
          span { first }
          return unless rest

          span(class: "wordmark-slash", aria: { hidden: "true" }) { SLASH }
          span { rest }
        end
      end
    end
  end
end
