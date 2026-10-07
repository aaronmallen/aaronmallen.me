# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class Capture < Component
          prop :pattern, Blog::Types::String
          prop :provider, Blog::Types::String
          prop :tags, Blog::Types::String
          prop :projects, Blog::Types::Array.of(Blog::Types::String)
          prop :choices, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :errors, Blog::Types::Hash

          def view_template
            Form(action: path(:admin_create_task_rule), class: "rule-capture") do
              Fields(
                pattern: @pattern, provider: @provider, tags: @tags, projects: @projects, choices: @choices,
                errors: @errors,
              )
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
