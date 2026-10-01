# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TaskForm < Component
          EXTERNAL = Blog::Types::TaskFilter["external"]
          LISTS = {
            Blog::Types::TaskFilter["today"] => ".lists.today",
            Blog::Types::TaskFilter["next"] => ".lists.next",
            Blog::Types::TaskFilter["someday"] => ".lists.someday",
          }.freeze
          FROM_TODAY = Blog::Types::TaskOrigin["today"]
          NEXT = Blog::Types::TaskFilter["next"]
          NOTE_HEIGHT = "160px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]
          TODAY = Blog::Types::TaskFilter["today"]

          prop :scope, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :task, Blog::Types::Instance(ROM::Struct).optional, default: nil
          prop :values, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :returns, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :autofocus, Blog::Types::Bool, default: false

          def view_template(&)
            Form(action:, class: "task-form", id: form_id) do
              @returns.each { |name, value| input(type: "hidden", name:, value:) }
              title_field
              note_field
              pair
              tags_field
              foot(&)
            end
          end

          private

          def action = @task ? path(:admin_update_task, id: @task.id) : path(:admin_create_task)

          def default_list = @returns[:origin] == FROM_TODAY ? TODAY : NEXT

          def field(name, label_key, **)
            Field(label: t(label_key), id: FieldError.id_for(name, @scope)) do
              Input(
                **FieldError.control_attributes(name, @errors, @scope), name: "task[#{name}]", value: @values[name], **,
              )
              FieldError(field: name, errors: @errors, scope: @scope)
            end
          end

          def foot
            div(class: "task-form-foot") do
              yield if block_given?
              Button(variant: :pri, type: "submit", small: true) do
                i(class: @task ? "fa-regular fa-floppy-disk" : "fa-solid fa-plus", aria: { hidden: "true" })
                span { t(@task ? ".update" : ".save") }
              end
            end
          end

          def form_id = ("task-#{@task.id}-form" if @task)

          def list_field
            Field(label: t(".list"), id: FieldError.id_for(:list, @scope)) do
              Select(
                **FieldError.control_attributes(:list, @errors, @scope),
                name: "task[list]",
                options: lists.transform_values { t(it) },
                selected: @values.fetch(:list) { default_list },
              )
              FieldError(field: :list, errors: @errors, scope: @scope)
            end
          end

          def lists = @task&.place == EXTERNAL ? LISTS.merge(EXTERNAL => ".lists.external") : LISTS

          def note_field
            label = t(".note")

            Field(label:) do
              MarkdownEditor(
                **FieldError.control_attributes(:note, @errors, @scope),
                name: "task[note]",
                value: @values[:note].to_s,
                height: NOTE_HEIGHT,
                renderer: RENDERER,
                label:,
                placeholder: t(".note_placeholder"),
              )
              FieldError(field: :note, errors: @errors, scope: @scope)
            end
          end

          def pair
            div(class: "task-form-pair") do
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
