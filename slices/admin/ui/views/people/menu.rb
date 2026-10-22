# frozen_string_literal: true

module Admin
  module UI
    module Views
      module People
        class Menu < View
          layout nil

          prop :person, Blog::Types::Instance(ROM::Struct)
          prop :return_to, Blog::Types::String.optional

          def view_template
            ContextMenu(label: Components::People::Avatar.name_of(@person), return_to: @return_to) do |menu|
              menu.link(t(".open"), href: act(:admin_person), icon: "fa-regular fa-address-card")
              menu.link(t(".edit"), href: act(:admin_edit_person), icon: :edit)
              copy(menu) if @person.key
              menu.separator
              menu.post(t(".remove"), action: act(:admin_delete_person), icon: :trash, warn: true,
                                      confirm: :delete)
            end
          end

          private

          def act(route) = path(route, id: @person.id)

          def copy(menu)
            menu.copy(t(".copy_mention"), text: mention, copied: t(".copied_mention"), icon: :copy, hint: mention)
          end

          def mention = t("ui.components.people.row.token", key: @person.key)
        end
      end
    end
  end
end
