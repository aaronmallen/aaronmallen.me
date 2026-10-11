# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Links
        class Foot < Component
          prop :link, Blog::Types::Instance(ROM::Struct)

          def view_template
            Button(
              small: true, variant: :warn, type: "submit", form: LinkForm.delete_id(@link),
              icon: "fa-regular fa-trash-can",
            ) { t(".delete") }
            Button(small: true, variant: :pri, type: "submit", form: LinkForm.form_id(@link)) { t(".save") }
          end
        end
      end
    end
  end
end
