# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Wordmark < Component
        SLASH = "/"
        SPLIT = " "

        include Deps["settings"]

        def view_template
          href = path(:root)
          owner = settings.owner_name

          a(class: "wordmark", href:, aria: { label: t(".label", owner:), current: current(href) }) do
            name(owner)
          end
        end

        private

        def current(href) = ("page" if request.path == href)

        def name(owner)
          first, rest = owner.split(SPLIT, 2)
          word(first)
          return unless rest

          span(class: "wordmark-slash", aria: { hidden: "true" }) { SLASH }
          word(rest)
        end

        def word(text)
          span do
            plain text[0]
            span(class: "wordmark-rest") { text[1..] }
          end
        end
      end
    end
  end
end
