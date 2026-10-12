# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tags
        class Menu < View
          include Components::Tags

          COLORS = Components::Swatches::COLORS.to_h do |color|
            [color, "ui.components.swatches.colors.#{Blog::UI::Components::Pill.for_tag_color(color)}"]
          end.freeze

          layout nil

          prop :tag, Blog::Types::Instance(ROM::Struct)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: name, return_to: @return_to) do |menu|
              menu.link(t(".rename"), href: "##{Editor.id_for(@tag)}", icon: "fa-solid fa-i-cursor")
              menu.sub(t(".color"), icon: "fa-solid fa-palette") { COLORS.each { color(menu, *it) } }
              menu.copy(t(".copy"), text: name, copied: t(".copied", tag: name), icon: "fa-regular fa-copy")
              menu.separator
              delete(menu)
            end
          end

          private

          def act(route) = path(route, id: @tag.id)

          def color(menu, color, label)
            fields = { scope: @tag.scope, "tag[name]": @tag.name, "tag[color]": color }

            menu.check(t(label), on: @tag.color == color, action: act(:admin_update_tag), fields:)
          end

          def delete(menu)
            confirm = t(".confirm_delete")
            fields = { scope: @tag.scope }
            icon = "fa-regular fa-trash-can"

            menu.post(t(".delete"), action: act(:admin_delete_tag), icon:, warn: true, confirm:, fields:)
          end

          def name = "#{Components::Tag::PREFIX}#{@tag.name}"
        end
      end
    end
  end
end
