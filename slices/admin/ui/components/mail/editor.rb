# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Editor < Component
          TOOLS = [
            %w[bold bold ⌘B], %w[italic italic ⌘I], %w[underline underline ⌘U], %w[strikeThrough strikethrough ⌘⇧X],
            nil, %w[link link ⌘K], nil,
            %w[insertUnorderedList list-ul ⌘⇧8], %w[insertOrderedList list-ol ⌘⇧7], %w[quote quote-left ⌘⇧9],
            %w[code code ⌘E], nil, %w[removeFormat text-slash ⌘\\],
          ].freeze
          LABELS = TOOLS.compact.to_h { [it.first, ".tools.#{it.first}"] }.freeze

          prop :scope, Blog::Types::String
          prop :label, Blog::Types::String
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash

          def view_template
            div(class: "mail-editor", data: { mail_editor: "" }) do
              tools
              link_bar
              label(class: "sr-only", for: id) { @label }
              textarea(**text_attributes) { @values[:body] }
              input(type: "hidden", name: "mail[html]", value: @values[:html], data: { mail_html: "" })
            end
            FieldError(field: :body, errors: @errors, scope: @scope)
          end

          private

          def id = FieldError.id_for(:body, @scope)

          def link_bar
            div(class: "mail-editor-link", hidden: true, data: { mail_link: "" }) do
              label(class: "sr-only", for: "#{@scope}-link") { t(".link_url") }
              Input(id: "#{@scope}-link", placeholder: t(".link_placeholder"))
              Button(small: true, data: { mail_link_add: "" }) { t(".add_link") }
              Button(variant: :gh, small: true, data: { mail_link_cancel: "" }) { t(".cancel") }
            end
          end

          def text_attributes
            own = { class: "mail-editor-text", name: "mail[body]", placeholder: @label, data: { mail_text: "" } }
            mix(own, FieldError.control_attributes(:body, @errors, @scope))
          end

          def tool(command, icon, key)
            name = t(LABELS.fetch(command))
            button(
              type: "button", title: "#{name} #{key}", aria: { label: name, pressed: "false" },
              data: { mail_command: command },
            ) { i(class: "fa-solid fa-#{icon}", aria: { hidden: "true" }) }
          end

          def tools
            div(class: "mail-editor-tools", role: "toolbar", aria: { label: t(".toolbar") }, hidden: true) do
              TOOLS.each { it ? tool(*it) : span(class: "mail-editor-sep") }
            end
          end
        end
      end
    end
  end
end
