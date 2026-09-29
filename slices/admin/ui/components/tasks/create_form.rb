# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CreateForm < Component
          LISTS = {
            Blog::Types::TaskFilter["today"] => ".lists.today",
            Blog::Types::TaskFilter["next"] => ".lists.next",
            Blog::Types::TaskFilter["someday"] => ".lists.someday",
          }.freeze
          NEXT = Blog::Types::TaskFilter["next"]

          prop :scope, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :values, Blog::Types::Hash, default: Dry::Core::Constants::EMPTY_HASH
          prop :errors, Blog::Types::Hash, default: Dry::Core::Constants::EMPTY_HASH
          prop :autofocus, Blog::Types::Bool, default: false

          def view_template(&)
            Form(action: path(:admin_create_task), class: "task-create-form") do
              title_field
              note_field
              pair
              tags_field
              foot(&)
            end
          end

          private

          def field(name, label_key, **)
            Field(label: t(label_key), id: FieldError.id_for(name, @scope)) do
              Input(
                **FieldError.control_attributes(name, @errors, @scope), name: "task[#{name}]", value: @values[name], **,
              )
              FieldError(field: name, errors: @errors, scope: @scope)
            end
          end

          def foot
            div(class: "task-create-foot") do
              yield if block_given?
              Button(variant: :pri, type: "submit", small: true) do
                i(class: "fa-solid fa-plus", aria: { hidden: "true" })
                span { t(".save") }
              end
            end
          end

          def list_field
            Field(label: t(".list"), id: FieldError.id_for(:list, @scope)) do
              Select(
                **FieldError.control_attributes(:list, @errors, @scope),
                name: "task[list]",
                options: LISTS.transform_values { t(it) },
                selected: @values.fetch(:list, NEXT),
              )
              FieldError(field: :list, errors: @errors, scope: @scope)
            end
          end

          def note_field
            Field(label: t(".note"), id: FieldError.id_for(:note, @scope)) do
              Textarea(
                **FieldError.control_attributes(:note, @errors, @scope),
                name: "task[note]",
                placeholder: t(".note_placeholder"),
                rows: 3,
                value: @values[:note],
              )
              FieldError(field: :note, errors: @errors, scope: @scope)
            end
          end

          def pair
            div(class: "task-editor-pair") do
              list_field
              SprintField(scope: @scope, scheduled:, today: @today)
            end
          end

          def scheduled = Blog::TimeZone.parse_day(@values[:sprint_on])

          def tags_field = field(:tags, ".tags", placeholder: t(".tags_placeholder"))

          def title_field = field(:title, ".title", autocomplete: "off", autofocus: @autofocus)
        end
      end
    end
  end
end
