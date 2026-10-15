# frozen_string_literal: true

module Admin
  module UI
    module Views
      module TaskRules
        class Menu < View
          layout nil

          prop :rule, Blog::Types::Instance(ROM::Struct)

          def view_template
            id = @rule.id

            ContextMenu(label: @rule.pattern) do |menu|
              menu.link(t(".edit"), href: path(:admin_task_rules), icon: :edit,
                                    dialog: Components::TaskRules::Row.toggle_id(id))
              menu.separator
              menu.post(t(".delete"), action: path(:admin_delete_task_rule, id:), icon: :trash,
                                      warn: true, confirm: t(".confirm_delete"))
            end
          end
        end
      end
    end
  end
end
