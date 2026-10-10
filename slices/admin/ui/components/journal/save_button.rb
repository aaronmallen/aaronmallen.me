# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class SaveButton < Component
          ICON = "fa-solid fa-feather"

          prop :body, Blog::Types::String
          prop :feather, Blog::Types::Bool, default: false

          def view_template(&)
            Button(
              variant: :pri, small: true, type: "submit", disabled: EntryFields.blank?(@body), icon: (ICON if @feather),
              data: { journal_save: "" }, &
            )
          end
        end
      end
    end
  end
end
