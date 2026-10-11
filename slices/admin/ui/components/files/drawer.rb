# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class Drawer < Component
          prop :share, Blog::Types::Instance(ROM::Struct)

          def self.id_for(share) = "#{ShareForm.scope(share)}-drawer"

          def view_template
            Dialog(**attributes) do |dialog|
              dialog.foot { Foot(share: @share) }
              ShareForm(share: @share)
            end
          end

          private

          def attributes
            id = self.class.id_for(@share)

            { id:, title_id: "#{id}-title", title: t(".title"), class: "wide file-drawer", data: { dialog: true } }
          end
        end
      end
    end
  end
end
