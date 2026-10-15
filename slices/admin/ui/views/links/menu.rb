# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Links
        class Menu < View
          include Components::Links

          layout nil

          prop :link, Blog::Types::Instance(ROM::Struct)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: Helpers::ShareLink.bare(short), return_to: @return_to) do |menu|
              opens(menu)
              menu.separator
              copies(menu)
              menu.separator
              delete(menu)
            end
          end

          private

          def act(route) = path(route, id: @link.id)

          def copies(menu)
            destination = @link.destination

            menu.copy(t(".copy_short"), text: short, copied: t(".copied_short"), icon: "fa-solid fa-link")
            menu.copy(t(".copy_destination"), text: destination, copied: t(".copied_destination"),
                                              icon: "fa-regular fa-copy")
            menu.copy(t(".copy_markdown"), text: markdown, copied: t(".copied_markdown"), icon: "fa-brands fa-markdown")
          end

          def delete(menu)
            confirm = t(".confirm_delete")

            menu.post(t(".delete"), action: act(:admin_delete_link), icon: "fa-regular fa-trash-can", warn: true,
                                    confirm:)
          end

          def markdown = Helpers::ShareLink.markdown(@link.title || Row.host(@link.destination), short)

          def opens(menu)
            dialog = ShareDrawer.id_for(LinkForm, @link)

            menu.link(t(".edit"), href: act(:admin_edit_link), icon: "fa-regular fa-pen-to-square", dialog:)
            menu.link(t(".open"), href: @link.destination, icon: "fa-solid fa-arrow-up-right-from-square",
                                  outbound: true)
          end

          def short = Helpers::ShareLink.for(@link.code)
        end
      end
    end
  end
end
