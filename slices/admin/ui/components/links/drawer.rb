# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Links
        class Drawer < Component
          prop :link, Blog::Types::Instance(ROM::Struct)

          def self.id_for(link) = "#{LinkForm.scope(link)}-drawer"

          def view_template
            Dialog(**attributes) do |dialog|
              dialog.foot { Foot(link: @link) }
              LinkForm(link: @link)
            end
          end

          private

          def attributes
            id = self.class.id_for(@link)

            { id:, title_id: "#{id}-title", title: t(".title"), class: "wide file-drawer", data: { dialog: true } }
          end
        end
      end
    end
  end
end
