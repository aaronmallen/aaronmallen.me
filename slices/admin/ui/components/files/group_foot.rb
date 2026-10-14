# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class GroupFoot < Component
          prop :group, Blog::Types::Instance(ROM::Struct)

          def view_template
            Button(
              small: true, variant: :warn, type: "submit", form: GroupForm.delete_id(@group),
              icon: "fa-regular fa-trash-can",
            ) { t(".delete") }
            Button(small: true, variant: :pri, type: "submit", form: GroupForm.form_id(@group)) { t(".save") }
          end
        end
      end
    end
  end
end
