# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class ProjectPick < Component
          NAME = "{name}"

          prop :choices, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :projects, Blog::Types::Array.of(Blog::Types::String)
          prop :scope, Blog::Types::String
          prop :control, Blog::Types::Hash

          def view_template
            return Hint(inline: true) { t(".no_projects") } if @choices.empty?

            group = {
              class: "rule-projects", role: "group", aria: { label: t(".projects") },
              data: { project_pick_boxes: "" },
            }
            div(**mix(@control, group)) { @choices.each { choice(it) } }
            pick
          end

          private

          def archived_label
            whitespace
            span(class: "rule-project-archived") { t(".archived") }
          end

          def choice(project)
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

          def pick
            list_id = "#{@scope}-projects-results"
            div(class: "project-pick", hidden: true, data: pick_data) do
              ul(class: "project-pick-chips", aria: { label: t(".chosen") }, data: { project_pick_chips: "" })
              div(class: "project-pick-box") do
                Icon("fa-solid fa-magnifying-glass")
                Input(type: "search", **mix(@control.except(:id), search_attributes(list_id)))
              end
              div(
                id: list_id, class: "project-pick-results", role: "listbox", hidden: true,
                aria: { label: t(".projects") }, data: { project_pick_results: "" },
              )
              p(class: "sr-only", role: "status", data: { project_pick_status: "" })
            end
          end

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

          def search_attributes(list_id)
            {
              id: "#{@scope}-projects-search", autocomplete: "off", role: "combobox",
              placeholder: t(".search_placeholder"),
              aria: { autocomplete: "list", controls: list_id, expanded: "false" },
              data: { project_pick_input: "" },
            }
          end
        end
      end
    end
  end
end
