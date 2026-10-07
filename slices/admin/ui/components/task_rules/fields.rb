# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class Fields < Component
          LABELS = { pattern: ".pattern", tags: ".tags" }.freeze
          PLACEHOLDERS = { pattern: ".pattern_placeholder", tags: ".tags_placeholder" }.freeze
          PROVIDERS = Blog::Types::TaskSourceProvider.values.to_h do |provider|
            [provider, "ui.components.task_rules.fields.providers.#{provider}"]
          end.freeze

          prop :pattern, Blog::Types::String
          prop :provider, Blog::Types::String
          prop :tags, Blog::Types::String
          prop :projects, Blog::Types::Array.of(Blog::Types::String)
          prop :choices, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :errors, Blog::Types::Hash
          prop :scope, Blog::Types::String, default: FieldError::SCOPE

          def view_template
            div(class: "rule-fields") do
              provider_field
              text_field(:pattern, @pattern)
              text_field(:tags, @tags)
              projects_field
            end
          end

          private

          def error_props(name) = { name:, errors: @errors, error: FieldError, scope: @scope }

          def project_choice(project)
            label(class: "choice") do
              input(
                class: "check", type: "checkbox", name: "rule[projects][]", value: project.id,
                checked: @projects.include?(project.id.to_s),
              )
              span { project.name }
            end
          end

          def projects_field
            Field(label: t(".projects"), **error_props(:projects)) do |control|
              if @choices.empty?
                Hint(inline: true) { t(".no_projects") }
              else
                group = { class: "rule-projects", role: "group", aria: { label: t(".projects") } }
                div(**mix(control, group)) { @choices.each { project_choice(it) } }
              end
            end
          end

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
