# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskTagRules
        class Capture < Component
          prop :pattern, Blog::Types::String
          prop :tags, Blog::Types::String
          prop :errors, Blog::Types::Hash

          def view_template
            Form(action: path(:admin_create_task_tag_rule), class: "rule-capture") do
              Fields(pattern: @pattern, tags: @tags, errors: @errors)
              div(class: "rule-capture-foot") do
                Hint(inline: true) { t(".note") }
                Button(variant: :pri, type: "submit") { t(".add") }
              end
            end
          end
        end
      end
    end
  end
end
