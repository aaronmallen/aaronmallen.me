# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Webmentions < Component
          prop :enabled, Blog::Types::Bool
          prop :received, Blog::Types::Integer

          def view_template
            Card(label: t(".heading")) do
              div(class: "form-stack") do
                Checkbox(switch: true, label: t(".accept"), name: "post[webmentions_enabled]", checked: @enabled)
                Hint { t(".hint") }
                Hint { t(".received", count: @received) } if @received.positive?
              end
            end
          end
        end
      end
    end
  end
end
