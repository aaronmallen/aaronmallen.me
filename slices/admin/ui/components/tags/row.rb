# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class Row < Component
          SEPARATOR = " · "
          USE_KEYS = %i[posts projects journal_entries tasks].to_h { [it, ".uses.#{it}"] }.freeze

          prop :tag, Blog::Types::Instance(ROM::Struct)
          prop :uses, Blog::Types::Hash
          prop :editing, Blog::Types::Hash.optional, default: nil
          prop :page, Blog::Types::Integer, default: 1

          def view_template
            div(class: "tag-row") do
              input(type: "checkbox", class: "sr-only tag-toggle", id: toggle_id, checked: editing?)
              label(class: "tag-name", for: toggle_id) { Tag(tag: @tag) }
              p(class: "tag-uses") { uses }
              acts
              editor
            end
          end

          private

          def acts
            div(class: "tag-acts") do
              label(class: "btn sm tag-pen", for: toggle_id, title: t(".edit")) do
                i(class: "fa-regular fa-pen-to-square", aria: { hidden: "true" })
                span(class: "sr-only") { t(".edit") }
              end
            end
          end

          def cancel = label(class: "btn sm gh", for: toggle_id) { t(".cancel") }

          def color_form
            Form(action: path(:admin_update_tag, id: @tag.id), class: "field") do
              scope_field
              page_field
              input(type: "hidden", name: "tag[name]", value: @tag.name)
              span(class: "f") { t(".color") }
              Swatches(name: "tag[color]", scope:, selected: @tag.color, submit: true)
            end
          end

          def editing? = @editing&.fetch(:id) == @tag.id

          def editor
            div(class: "tag-editor") do
              div(class: "tag-editor-row") do
                rename_form
                color_form
              end
              FieldError(field: :name, errors:, scope:)
              foot
            end
          end

          def errors = editing? ? @editing[:errors] : Blog::Constants::EMPTY_HASH

          def foot
            div(class: "tag-editor-foot") do
              remove
              cancel
              save
            end
          end

          def held = @uses.values.sum

          def held? = held.positive?

          def name = editing? ? @editing[:name] : @tag.name

          def page_field = @page > 1 && input(type: "hidden", name: "page", value: @page)

          def remove
            Form(**remove_attributes) do
              scope_field
              Button(variant: :warn, type: "submit", small: true, disabled: held?) do
                i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
                span { t(".remove") }
              end
            end
          end

          def remove_attributes
            {
              action: path(:admin_delete_tag, id: @tag.id),
              data: { confirm: t(".confirm_remove", tag: @tag.name) },
              title: held? ? t(".held", count: held) : nil,
            }
          end

          def rename_form
            Form(action: path(:admin_update_tag, id: @tag.id), class: "field", id: rename_id) do
              scope_field
              page_field
              label(class: "f", for: FieldError.id_for(:name, scope)) { t(".rename") }
              Input(**FieldError.control_attributes(:name, errors, scope), name: "tag[name]", value: name)
            end
          end

          def rename_id = "tag-#{@tag.id}-form"

          def save
            Button(variant: :pri, type: "submit", small: true, form: rename_id) do
              i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
              span { t(".save") }
            end
          end

          def scope = "tag-#{@tag.id}"

          def scope_field = input(type: "hidden", name: "scope", value: @tag.scope)

          def toggle_id = "tag-#{@tag.id}-edit"

          def uses
            return t(".unused") unless held?

            USE_KEYS.filter_map { |kind, key| t(key, count: @uses[kind]) if @uses[kind] }.join(SEPARATOR)
          end
        end
      end
    end
  end
end
