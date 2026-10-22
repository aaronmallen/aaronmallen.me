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
            ContextMenu(label: @person.name, return_to: @return_to) do |menu|
              menu.link(t(".edit"), href: act(:admin_edit_person), icon: :edit)
              if @person.key
                menu.copy(t(".copy_mention"), text: mention, copied: t(".copied_mention"), icon: :copy,
                                              hint: mention)
              end
              menu.separator
              menu.post(t(".remove"), action: act(:admin_delete_person), icon: :trash, warn: true,
                                      confirm: :remove)
            end
          end

          private

          def act(route) = path(route, id: @person.id)

          def mention = t("ui.components.people.list.token", key: @person.key)
        end
      end
    end
  end
end
