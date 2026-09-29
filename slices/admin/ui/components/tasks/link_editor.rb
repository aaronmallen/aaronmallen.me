# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class LinkEditor < Component
          KINDS = {
            Blog::Types::TaskLinkKind["blocks"] => ".kinds.blocks",
            Blog::Types::TaskLinkKind["blocked_by"] => ".kinds.blocked_by",
            Blog::Types::TaskLinkKind["relates"] => ".kinds.relates",
            Blog::Types::TaskLinkKind["duplicates"] => ".kinds.duplicates",
          }.freeze
          PLACES = {
            Blog::Types::TaskStatus["canceled"] => ".places.canceled",
            Blog::Types::TaskStatus["done"] => ".places.done",
            Blog::Types::TaskStatus["in_progress"] => ".places.in_progress",
            Blog::Types::TaskFilter["today"] => ".places.today",
            Blog::Types::TaskFilter["next"] => ".places.next",
            Blog::Types::TaskFilter["someday"] => ".places.someday",
          }.freeze
          BY_STATUS = [
            Blog::Types::TaskStatus["canceled"], Blog::Types::TaskStatus["done"], Blog::Types::TaskStatus["in_progress"],
          ].freeze
          PREFIX = "#"
          TODAY = Blog::Types::TaskFilter["today"]

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String
          prop :types, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :linking, Blog::Types::Hash.optional, default: nil

          def view_template
            div(class: "task-link-editor") do
              Field(label: t(".label"), id: query_id) do
                links unless @task.links.empty?
                add_form
                find_form
                field_errors
                targets if searched?
              end
            end
          end

          private

          def add_form
            Form(action: path(:admin_link_task, id: @task.id), id: add_form_id) { return_fields }
          end

          def add_form_id = "#{scope}-add"

          def errors = @linking ? @linking[:errors] : Dry::Core::Constants::EMPTY_HASH

          def field_errors
            FieldError(field: :kind, errors:, scope:)
            FieldError(field: :other_id, errors:, scope:)
          end

          def find_form
            Form(method: "get", action: path(:admin_tasks), class: "task-link-find") do
              input(type: "hidden", name: "filter", value: @tab)
              input(type: "hidden", name: "link", value: @task.id)
              kind_select
              Input(
                **FieldError.control_attributes(:other_id, errors, scope),
                type: "search", name: "link_q", value: query, placeholder: t(".placeholder"),
              )
              Button(type: "submit", small: true) { t(".find") }
            end
          end

          def key(task) = "#{PREFIX}#{task.id}"

          def key_badge(task)
            span(class: ["task-key", Blog::UI::Components::Pill.for_tag_color(type_of(task)&.color)&.to_s]) { key(task) }
          end

          def kind_select
            Select(
              **FieldError.control_attributes(:kind, errors, scope),
              name: "link[kind]", form: add_form_id, aria: { label: t(".kind") },
              options: KINDS.transform_values { t(it) }, selected: @linking&.fetch(:kind),
            )
          end

          def link_row(link)
            div(class: "task-link-row") do
              span(class: "task-link-label") { t(Links.label_key(link)) }
              TaskKey(task: link.task, type: type_of(link.task))
              span(class: "task-link-title") { link.task.title }
              span(class: "task-link-place") { place(link.task) }
              unlink_form(link)
            end
          end

          def links
            div(class: "task-link-list") { @task.links.each { link_row(it) } }
          end

          def place(task) = t(PLACES.fetch(BY_STATUS.include?(task.status) ? task.status : task.list || TODAY))

          def query = @linking ? @linking[:query].to_s : Dry::Core::Constants::EMPTY_STRING

          def query_id = FieldError.id_for(:other_id, scope)

          def return_fields
            input(type: "hidden", name: "filter", value: @tab)
            input(type: "hidden", name: "origin", value: @origin)
          end

          def scope = "task-#{@task.id}-link"

          def searched? = !query.empty?

          def target(task)
            button(
              type: "submit", form: add_form_id, name: "link[other_id]", value: task.id, class: "task-link-target",
            ) do
              key_badge(task)
              span(class: "task-link-title") { task.title }
              span(class: "task-link-place") { place(task) }
            end
          end

          def targets
            found = @linking.fetch(:targets, Dry::Core::Constants::EMPTY_ARRAY)
            return Hint { t(".no_match") } if found.empty?

            div(class: "task-link-targets") { found.each { target(it) } }
          end

          def type_of(task) = @types.find { it.id == task.task_type_id }

          def unlink_form(link)
            label = t(".remove", key: key(link.task))

            Form(action: path(:admin_unlink_task, id: @task.id, other_id: link.task.id)) do
              return_fields
              Button(type: "submit", variant: :gh, small: true, title: label, aria: { label: }) do
                i(class: "fa-solid fa-xmark", aria: { hidden: "true" })
              end
            end
          end
        end
      end
    end
  end
end
