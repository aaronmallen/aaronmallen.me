# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class Minted < Component
          ID = "minted-token"

          prop :value, Blog::Types::String

          def view_template
            div(class: "token-minted") do
              Icon(["fa-solid fa-key", "token-minted-icon"])
              div(class: "token-minted-body") do
                label(class: "token-minted-title", for: ID) { t(".title") }
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
