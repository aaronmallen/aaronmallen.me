# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Account < Component
          prop :chip, Blog::Types::Array.of(Blog::Types::String)

          def view_template
            name, tone = @chip
            span(class: ["mail-account", tone]) do
              span(class: "mail-dot", aria: { hidden: "true" })
              plain name
            end
          end
        end
      end
    end
  end
end
