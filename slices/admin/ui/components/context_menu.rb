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

        def clear(label, form:)
          button(type: "button", **item(data: { bulk_clear: form })) do
            inner(label, icon: "fa-regular fa-square-minus")
          end
        end

        def click(label, target:, icon:)
          button(type: "button", **item(data: { menu_click: target })) { inner(label, icon:) }
        end

        def copy(label, text:, copied:, icon:, hint: nil)
          button(type: "button", **item(data: { copy: text, copied: })) { inner(label, icon:, hint:) }
        end

        def field(label, action:, name:, pattern:, invalid:, suggest:, fields: Blog::Constants::EMPTY_HASH)
          Form(action:, class: "ctx-field", novalidate: true, data: { morph: true }) do
            hidden(fields)
            div(class: "contents", role: "menuitem", aria: { label: }) do
              Icon(:add)
              input(
                type: "text", name:, pattern:, placeholder: label, autocomplete: "off", class: "ctx-input",
                tabindex: "-1", aria: { label: }, data: { context_item: true, invalid: },
              )
            end
            suggestions(suggest)
          end
        end

        def link(label, href:, icon:, key: nil, hint: nil, outbound: false, dialog: nil)
          extra = outbound ? OUTBOUND : Blog::Constants::EMPTY_HASH
          a(href:, **item(**Dialog.opens(dialog)), **extra) { inner(label, icon:, hint:, key:) }
        end

        def post(label, action:, icon: nil, hint: nil, fields: Blog::Constants::EMPTY_HASH, confirm: nil, morph: true,
                 **)
          Form(action:, data: { morph: (true if morph) }) do
            hidden(fields)
            button(type: "submit", **item(data: confirm ? { confirm_inline: worded(confirm) } : {}, **)) do
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
            field(new_tag, name: "tag", pattern: TAG_PATTERN, invalid:, suggest: tags, **yield(nil, false))
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
          HiddenFields(values: { return_to: @return_to, **fields })
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

        def suggestions(tags)
          choices = tags.map { { name: it.name, color: Blog::UI::Components::Pill.for_tag_color(it.color)&.to_s } }

          div(class: "ctx-suggest", hidden: true, data: { menu_suggest: JSON.generate(choices) })
        end

        def worded(confirm) = confirm.is_a?(Symbol) ? t([".confirm", confirm].join(".")) : confirm
      end
    end
  end
end
