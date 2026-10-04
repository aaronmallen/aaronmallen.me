# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskTagRules
        class Fields < Component
          LABELS = { pattern: ".pattern", tags: ".tags" }.freeze
          PLACEHOLDERS = { pattern: ".pattern_placeholder", tags: ".tags_placeholder" }.freeze

          prop :pattern, Blog::Types::String
          prop :tags, Blog::Types::String
          prop :errors, Blog::Types::Hash
          prop :scope, Blog::Types::String, default: FieldError::SCOPE

          def view_template
            div(class: "rule-fields") do
              field(:pattern, @pattern)
              field(:tags, @tags)
            end
          end

          private

          def field(name, value)
            Field(label: t(LABELS.fetch(name)), id: FieldError.id_for(name, @scope)) do
              Input(
                **FieldError.control_attributes(name, @errors, @scope),
                autocomplete: "off",
                name: "rule[#{name}]",
                placeholder: t(PLACEHOLDERS.fetch(name)),
                value:,
              )
              FieldError(field: name, errors: @errors, scope: @scope)
            end
          end
        end
      end
    end
  end
end
