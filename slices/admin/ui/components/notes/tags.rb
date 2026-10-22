# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Notes
        class Tags < Component
          prop :note, Blog::Types::Instance(ROM::Struct)
          prop :editing, Blog::Types::Bool, default: false

          def view_template
            div(class: "nt-tags", aria: { label: t(".label") },
                data: { note_tags: ("" if @editing), remove: (t(".remove", tag: "{tag}") if @editing) }) do
              @note.tags.each { pill(it) }
              add
            end
          end

          private

          def add
            details(class: "nt-add") do
              summary(class: "nt-ta-add") do
                Icon("fa-solid fa-tag")
                plain @note.tags.empty? ? t(".add_tags") : t(".add")
              end
              @editing ? field : Form(action: path(:admin_tag_note, id: @note.id), data: { morph: true }) { field }
            end
          end

          def field
            input(
              class: "nt-ti", type: "text", name: ("tag" unless @editing), autocomplete: "off",
              placeholder: t(".placeholder"), aria: { label: t(".new") }, data: { note_tag_input: "" },
            )
          end

          def pill(tag)
            span(class: "nt-tg", data: { note_tag: tag.name }) do
              Tag(tag:)
              remove(tag.name)
            end
          end

          def remove(name)
            label = t(".remove", tag: name)
            x = -> { button(type: @editing ? "button" : "submit", class: "nt-x", aria: { label: }) { Icon(:close) } }
            return x.call if @editing

            Form(action: path(:admin_untag_note, id: @note.id), data: { morph: true }) do
              HiddenFields(values: { tag: name })
              x.call
            end
          end
        end
      end
    end
  end
end
