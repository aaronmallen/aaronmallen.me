# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Files
        class Foot < Component
          prop :share, Blog::Types::Instance(ROM::Struct)

          def view_template
            Button(
              small: true, variant: :warn, type: "submit", form: ShareForm.delete_id(@share),
              icon: "fa-regular fa-trash-can",
            ) { t(".delete") }
            Button(small: true, variant: :pri, type: "submit", form: ShareForm.form_id(@share)) { t(".save") }
          end
        end
      end
    end
  end
end
