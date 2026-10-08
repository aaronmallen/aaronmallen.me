# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TaskRules
        class Row < Component
          SEPARATOR = ", "

          prop :rule, Blog::Types::Instance(ROM::Struct)
          prop :editing, Blog::Types::Hash.optional, default: nil
          prop :choices, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            div(class: "rule-row", data: { key_row: true }) do
              input(type: "checkbox", class: "sr-only rule-toggle", id: toggle_id, checked: editing?)
              head
              p(class: "rule-tags") do
                @rule.tags.each { Tag(tag: it) }
                @rule.projects.each { |project| span(class: "rule-project") { project.name } }
              end
              acts
              editor
            end
          end

          private

          def acts
            div(class: "rule-acts") do
              label(class: "bt sm rule-pen", for: toggle_id, title: t(".edit")) do
                Icon("fa-regular fa-pen-to-square")
                span(class: "sr-only") { t(".edit") }
              end
            end
          end

          def cancel = label(class: "bt sm gh", for: toggle_id) { t(".cancel") }

          def delete
            Form(
              action: path(:admin_delete_task_rule, id: @rule.id),
              data: { confirm: t(".confirm_delete", pattern: @rule.pattern, provider:) },
            ) do
              Button(variant: :warn, type: "submit", small: true, icon: "fa-regular fa-trash-can") { t(".delete") }
            end
          end

          def editing? = @editing&.fetch(:id) == @rule.id

          def editor
            div(class: "rule-editor") do
              Form(action: path(:admin_update_task_rule, id: @rule.id), id: form_id) do
                Fields(**values, choices: @choices, scope:)
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
            Button(variant: :pri, type: "submit", small: true, form: form_id, icon: "fa-regular fa-floppy-disk") do
              t(".save")
            end
          end

          def scope = "rule-#{@rule.id}"

          def toggle_id = "rule-#{@rule.id}-edit"

          def values
            return @editing.slice(:errors, :pattern, :provider, :tags, :projects) if editing?

            {
              errors: Blog::Constants::EMPTY_HASH, pattern: @rule.pattern, provider: @rule.provider,
              tags: @rule.tags.map(&:name).join(SEPARATOR), projects: @rule.projects.map { it.id.to_s },
            }
          end
        end
      end
    end
  end
end
