# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskTagRules
        class Fields < Component
          LABELS = { pattern: ".pattern", tags: ".tags" }.freeze
          PLACEHOLDERS = { pattern: ".pattern_placeholder", tags: ".tags_placeholder" }.freeze
          PROVIDERS = Blog::Types::TaskSourceProvider.values.to_h do |provider|
            [provider, "ui.components.task_tag_rules.fields.providers.#{provider}"]
          end.freeze

          prop :pattern, Blog::Types::String
          prop :provider, Blog::Types::String
          prop :tags, Blog::Types::String
          prop :errors, Blog::Types::Hash
          prop :scope, Blog::Types::String, default: FieldError::SCOPE

          def view_template
            div(class: "rule-fields") do
              provider_field
              text_field(:pattern, @pattern)
              text_field(:tags, @tags)
            end
          end

          private

          def error_props(name) = { name:, errors: @errors, error: FieldError, scope: @scope }

          def provider_field
            Field(label: t(".provider"), **error_props(:provider)) do |control|
              Select(
                **control,
                name: "rule[provider]",
                options: PROVIDERS.transform_values { t(it) },
                selected: @provider,
              )
            end
          end

          def text_field(name, value)
            Field(label: t(LABELS.fetch(name)), **error_props(name)) do |control|
              Input(
                **control,
                autocomplete: "off",
                name: "rule[#{name}]",
                placeholder: t(PLACEHOLDERS.fetch(name)),
                value:,
              )
            end
          end
        end
      end
    end
  end
end
