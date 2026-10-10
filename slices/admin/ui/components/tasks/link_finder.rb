# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class LinkFinder < Component
          KINDS = {
            Blog::Types::TaskLinkKind["blocks"] => ".kinds.blocks",
            Blog::Types::TaskLinkKind["blocked_by"] => ".kinds.blocked_by",
            Blog::Types::TaskLinkKind["relates"] => ".kinds.relates",
            Blog::Types::TaskLinkKind["duplicates"] => ".kinds.duplicates",
          }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String
          prop :linking, Blog::Types::Hash.optional, default: nil

          def self.query_id(task) = FieldError.id_for(:other_id, scope(task))

          def self.scope(task) = "task-#{task.id}-link"

          def view_template
            Form(action: path(:admin_link_task, id: @task.id), id: form_id) do
              HiddenFields(values: { filter: @tab, origin: @origin })
            end
            find_row
            FieldError(field: :kind, errors:, scope:)
            FieldError(field: :other_id, errors:, scope:)
            targets unless query.empty?
          end

          private

          def errors = @linking ? @linking[:errors] : Blog::Constants::EMPTY_HASH

          def find_row
            div(class: "task-link-find") do
              kind_select
              Input(
                **FieldError.control_attributes(:other_id, errors, scope),
                type: "search", name: "link_q", form: form_id, value: query, placeholder: t(".placeholder"),
              )
              Button(
                type: "submit", small: true, form: form_id, name: "link_find", value: "1",
                data: { task_find: path(:admin_task, id: @task.id, filter: @tab, origin: @origin) },
              ) { t(".find") }
            end
          end

          def form_id = "#{scope}-add"

          def kind_select
            Select(
              **FieldError.control_attributes(:kind, errors, scope),
              name: "link[kind]", form: form_id, aria: { label: t(".kind") },
              options: KINDS.transform_values { t(it) }, selected: @linking&.fetch(:kind),
            )
          end

          def query = @linking ? @linking[:query].to_s : Blog::Constants::EMPTY_STRING

          def scope = self.class.scope(@task)

          def target(task)
            button(type: "submit", form: form_id, name: "link[other_id]", value: task.id, class: "task-link-target") do
              span(class: "record-key") { RecordKey.key(task.id) }
              span(class: "task-link-title") { task.title }
              span(class: "task-link-place") { t(LinkRow.place_key(task)) }
            end
          end

          def targets
            found = @linking.fetch(:targets, Blog::Constants::EMPTY_ARRAY)
            return Hint { t(".no_match") } if found.empty?

            div(class: "task-link-targets") { found.each { target(it) } }
          end
        end
      end
    end
  end
end
