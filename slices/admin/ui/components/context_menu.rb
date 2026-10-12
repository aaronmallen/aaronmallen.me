# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ContextMenu < Component
        BLANK = "ctx-blank"
        CHECK = "fa-solid fa-check"
        ITEM = "ctx-item"
        MENU = { class: "ctx", role: "menu", tabindex: "-1" }.freeze
        TAG_PATTERN = '\s*[A-Za-z0-9]+(-[A-Za-z0-9]+)*\s*'

        prop :label, Blog::Types::String
        prop :return_to, Blog::Types::String.optional, default: nil

        def check(label, on:, **)
          post(label, icon: on ? CHECK : nil, role: "menuitemcheckbox", aria: { checked: on.to_s }, **)
        end

        def copy(label, text:, copied:, icon:, hint: nil)
          button(type: "button", **item(data: { copy: text, copied: })) { inner(label, icon:, hint:) }
        end

        def field(label, action:, name:, pattern:, invalid:, fields: Blog::Constants::EMPTY_HASH)
          Form(action:, class: "ctx-field", novalidate: true, data: { morph: true }) do
            hidden(fields)
            Icon("fa-solid fa-plus")
            input(
              type: "text", name:, pattern:, placeholder: label, autocomplete: "off", class: "ctx-input",
              tabindex: "-1", aria: { label: }, data: { context_item: true, invalid: },
            )
          end
        end

        def link(label, href:, icon:, key: nil, outbound: false, dialog: nil)
          data = dialog ? { dialog_open: dialog } : Blog::Constants::EMPTY_HASH
          a(href:, **item(data:), **(outbound ? OUTBOUND : Blog::Constants::EMPTY_HASH)) { inner(label, icon:, key:) }
        end

        def post(label, action:, icon: nil, hint: nil, fields: Blog::Constants::EMPTY_HASH, confirm: nil, **)
          Form(action:, data: { morph: true }) do
            hidden(fields)
            button(type: "submit", **item(data: confirm ? { confirm_inline: confirm } : {}, **)) do
              inner(label, icon:, hint:)
            end
          end
        end

        def separator = hr

        def sub(label, icon:, hint: nil, &)
          div(class: "ctx-sub") do
            button(type: "button", **item(aria: { haspopup: "menu", expanded: "false" })) do
              inner(label, icon:, hint:)
              Icon("fa-solid fa-chevron-right ctx-more")
            end
            div(**MENU, aria: { label: }, hidden: true, &)
          end
        end

        def tags(label, names:, tags:, new_tag:, invalid:)
          sub(label, icon: "fa-solid fa-tag", hint: (names.size.to_s unless names.empty?)) do
            tags.each do |tag|
              on = names.include?(tag.name)
              check("#{Tag::PREFIX}#{tag.name}", on:, **yield(tag.name, on))
            end
            separator unless tags.empty?
            field(new_tag, name: "tag", pattern: TAG_PATTERN, invalid:, **yield(nil, false))
          end
        end

        def view_template
          div(**MENU, aria: { label: @label }, data: { context_menu: true }) do
            p(class: "ctx-head", title: @label) { @label }
            yield(self)
          end
        end

        private

        def hidden(fields)
          HiddenFields(values: { return_to: @return_to, **fields }.compact)
        end

        def inner(label, icon:, hint: nil, key: nil)
          Icon(icon || BLANK)
          span(class: "ctx-label") { label }
          span(class: "ctx-hint") { hint } if hint
          kbd(class: "kbd") { key } if key
        end

        def item(role: "menuitem", data: {}, warn: false, **attributes)
          { class: [ITEM, ("ctx-warn" if warn)], role:, tabindex: "-1", data: { context_item: true, **data },
            **attributes }
        end
      end
    end
  end
end
