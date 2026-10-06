# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskTagRules
        class Row < Component
          SEPARATOR = ", "

          prop :rule, Blog::Types::Instance(ROM::Struct)
          prop :editing, Blog::Types::Hash.optional, default: nil

          def view_template
            div(class: "rule-row", data: { key_row: true }) do
              input(type: "checkbox", class: "sr-only rule-toggle", id: toggle_id, checked: editing?)
              head
              p(class: "rule-tags") { @rule.tags.each { Tag(tag: it) } }
              acts
              editor
            end
          end

          private

          def acts
            div(class: "rule-acts") do
              label(class: "btn sm rule-pen", for: toggle_id, title: t(".edit")) do
                i(class: "fa-regular fa-pen-to-square", aria: { hidden: "true" })
                span(class: "sr-only") { t(".edit") }
              end
            end
          end

          def cancel = label(class: "btn sm gh", for: toggle_id) { t(".cancel") }

          def delete
            Form(
              action: path(:admin_delete_task_tag_rule, id: @rule.id),
              data: { confirm: t(".confirm_delete", pattern: @rule.pattern, provider:) },
            ) do
              Button(variant: :warn, type: "submit", small: true) do
                i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
                span { t(".delete") }
              end
            end
          end

          def editing? = @editing&.fetch(:id) == @rule.id

          def editor
            div(class: "rule-editor") do
              Form(action: path(:admin_update_task_tag_rule, id: @rule.id), id: form_id) do
                Fields(**values, scope:)
              end
              Hint { t(".note") }
              foot
            end
          end

          def foot
            div(class: "rule-editor-foot") do
              delete
              cancel
              save
            end
          end

          def form_id = "rule-#{@rule.id}-form"

          def head
            div(class: "rule-head") do
              span(class: "rule-provider") { provider }
              label(class: "rule-pattern", for: toggle_id) { @rule.pattern }
            end
          end

          def provider = t(Fields::PROVIDERS.fetch(@rule.provider))

          def save
            Button(variant: :pri, type: "submit", small: true, form: form_id) do
              i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
              span { t(".save") }
            end
          end

          def scope = "rule-#{@rule.id}"

          def toggle_id = "rule-#{@rule.id}-edit"

          def values
            return @editing.slice(:errors, :pattern, :provider, :tags) if editing?

            {
              errors: Blog::Constants::EMPTY_HASH, pattern: @rule.pattern, provider: @rule.provider,
              tags: @rule.tags.map(&:name).join(SEPARATOR),
            }
          end
        end
      end
    end
  end
end
