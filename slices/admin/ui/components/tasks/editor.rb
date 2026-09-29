# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Editor < Component
          LISTS = {
            Blog::Types::TaskFilter["today"] => ".lists.today",
            Blog::Types::TaskFilter["next"] => ".lists.next",
            Blog::Types::TaskFilter["someday"] => ".lists.someday",
          }.freeze
          EXTERNAL = Blog::Types::TaskFilter["external"]
          ORIGIN = Blog::Types::TaskOrigin["tasks"]
          TAG_SEPARATOR = ", "

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :toggle, Blog::Types::String
          prop :editing, Blog::Types::Hash.optional, default: nil
          prop :origin, Blog::Types::String, default: ORIGIN
          prop :scheduled, Blog::Types::Date.optional, default: nil

          def view_template(&)
            div(class: "task-editor") do
              Form(action: path(:admin_update_task, id: @task.id), class: "task-editor-form", id:, &fields)
              yield
              foot
            end
          end

          private

          def cancel = label(class: "btn sm gh", for: @toggle) { t(".cancel") }

          def delete_form
            Form(
              action: path(:admin_delete_task, id: @task.id),
              data: { confirm: t(".confirm_delete", task: @task.title) },
            ) do
              hidden_fields
              Button(variant: :warn, type: "submit", small: true) do
                i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
                span { t(".delete") }
              end
            end
          end

          def editing? = @editing&.fetch(:id) == @task.id

          def errors = editing? ? @editing[:errors] : Dry::Core::Constants::EMPTY_HASH

          def field(name, label_key, value, **)
            Field(label: t(label_key), id: FieldError.id_for(name, scope)) do
              Input(**FieldError.control_attributes(name, errors, scope), name: "task[#{name}]", value:, **)
              FieldError(field: name, errors:, scope:)
            end
          end

          def fields
            proc do
              hidden_fields
              title_field
              note_field
              pair
              tags_field
            end
          end

          def foot
            div(class: "task-editor-foot") do
              delete_form
              cancel
              save
            end
          end

          def hidden_fields
            input(type: "hidden", name: "filter", value: @filter)
            input(type: "hidden", name: "origin", value: @origin)
          end

          def id = "task-#{@task.id}-form"

          def list = editing? ? @editing[:list] : @task.place

          def list_field
            Field(label: t(".list"), id: FieldError.id_for(:list, scope)) do
              Select(
                **FieldError.control_attributes(:list, errors, scope),
                name: "task[list]",
                options: lists.transform_values { t(it) },
                selected: list,
              )
              FieldError(field: :list, errors:, scope:)
            end
          end

          def lists = @task.place == EXTERNAL ? LISTS.merge(EXTERNAL => ".lists.external") : LISTS

          def note = editing? ? @editing[:note] : @task.note

          def note_field
            Field(label: t(".note"), id: FieldError.id_for(:note, scope)) do
              Textarea(
                **FieldError.control_attributes(:note, errors, scope),
                name: "task[note]",
                placeholder: t(".note_placeholder"),
                rows: 3,
                value: note,
              )
              FieldError(field: :note, errors:, scope:)
            end
          end

          def pair
            div(class: "task-editor-pair") do
              list_field
              sprint_field
            end
          end

          def save
            Button(variant: :pri, type: "submit", small: true, form: id) do
              i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
              span { t(".save") }
            end
          end

          def scope = "task-#{@task.id}"

          def sprint_field = SprintField(scope:, scheduled: @scheduled, today: @today)

          def tags = editing? ? @editing[:tags] : @task.tags.map(&:name).join(TAG_SEPARATOR)

          def tags_field = field(:tags, ".tags", tags, placeholder: t(".tags_placeholder"))

          def title = editing? ? @editing[:title] : @task.title

          def title_field = field(:title, ".title", title)
        end
      end
    end
  end
end
