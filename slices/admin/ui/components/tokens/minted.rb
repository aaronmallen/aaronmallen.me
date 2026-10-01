# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class Minted < Component
          ID = "minted-token"

          prop :value, Blog::Types::String

          def view_template
            Card(title: t(".title")) do
              div(class: "token-minted") do
                label(class: "sr-only", for: ID) { t(".label") }
                Input(id: ID, readonly: true, value: @value, autocomplete: "off", spellcheck: "false")
                Hint { t(".hint") }
              end
            end
          end
        end
      end
    end
  end
end
