# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class GroupDrawer < Component
          prop :group, Blog::Types::Instance(ROM::Struct)

          def self.id_for(group) = "#{GroupForm.scope(group)}-drawer"

          def view_template
            id = self.class.id_for(@group)

            title_id = "#{id}-title"

            Dialog(id:, title_id:, title: t(".title"), class: "wide file-drawer", data: { dialog: true }) do |dialog|
              dialog.foot { GroupFoot(group: @group) }
              GroupForm(group: @group)
            end
          end
        end
      end
    end
  end
end
