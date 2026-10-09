# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class Fields < Component
          NAME = "{name}"
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

          def archived_label
            whitespace
            span(class: "rule-project-archived") { t(".archived") }
          end

          def error_props(name) = { name:, errors: @errors, error: FieldError, scope: @scope }

          def pick_data
            {
              project_pick: "",
              project_pick_archived: t(".archived"),
              project_pick_none: t(".no_match"),
              project_pick_remove: t(".remove", name: NAME),
              project_pick_results_one: t(".results.one"),
              project_pick_results_other: t(".results.other"),
            }
          end

          def project_choice(project)
            label(class: "choice") do
              input(
                class: "check", type: "checkbox", name: "rule[projects][]", value: project.id,
                checked: @projects.include?(project.id.to_s),
                data: { project_name: project.name, project_archived: project.archived_on ? "" : nil },
              )
              span { project.name }
              archived_label if project.archived_on
            end
          end

          def project_pick(control)
            list_id = "#{@scope}-projects-results"
            div(class: "project-pick", hidden: true, data: pick_data) do
              ul(class: "project-pick-chips", aria: { label: t(".chosen") }, data: { project_pick_chips: "" })
              div(class: "project-pick-box") do
                Icon("fa-solid fa-magnifying-glass")
                Input(type: "search", **mix(control.except(:id), search_attributes(list_id)))
              end
              div(
                id: list_id, class: "project-pick-results", role: "listbox", hidden: true,
                aria: { label: t(".projects") }, data: { project_pick_results: "" },
              )
              p(class: "sr-only", role: "status", data: { project_pick_status: "" })
            end
          end

          def projects_field
            Field(label: t(".projects"), **error_props(:projects)) do |control|
              if @choices.empty?
                Hint(inline: true) { t(".no_projects") }
              else
                group = {
                  class: "rule-projects", role: "group", aria: { label: t(".projects") },
                  data: { project_pick_boxes: "" },
                }
                div(**mix(control, group)) { @choices.each { project_choice(it) } }
                project_pick(control)
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

          def search_attributes(list_id)
            {
              id: "#{@scope}-projects-search", autocomplete: "off", role: "combobox",
              placeholder: t(".search_placeholder"),
              aria: { autocomplete: "list", controls: list_id, expanded: "false" },
              data: { project_pick_input: "" },
            }
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
