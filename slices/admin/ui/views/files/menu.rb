# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Files
        class Menu < View
          include Components::Files

          layout nil

          prop :share, Blog::Types::Instance(ROM::Struct)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: @share.filename, return_to: @return_to) do |menu|
              opens(menu)
              menu.separator
              copies(menu)
              menu.separator
              delete(menu)
            end
          end

          private

          def act(route) = path(route, id: @share.id)

          def copies(menu)
            hint = bare_url(link)

            menu.copy(t(".copy_link"), text: link, copied: t(".copied_link"), icon: "fa-solid fa-link", hint:)
            menu.copy(t(".copy_markdown"), text: markdown, copied: t(".copied_markdown"), icon: "fa-brands fa-markdown")
          end

          def delete(menu)
            confirm = t(".confirm_delete")

            menu.post(t(".delete"), action: act(:admin_delete_file), icon: :trash, warn: true,
                                    confirm:)
          end

          def link = Helpers::ShareLink.for(@share.short)

          def markdown = Helpers::ShareLink.file_markdown(@share, link)

          def opens(menu)
            dialog = ShareDrawer.id_for(ShareForm, @share)

            menu.link(t(".details"), href: act(:admin_edit_file), icon: :edit, dialog:)
            menu.link(t(".open"), href: link, icon: :outbound, outbound: true)
          end
        end
      end
    end
  end
end
