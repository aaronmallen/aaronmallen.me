# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class EditorActions < Component
          prop :archived, Blog::Types::Bool
          prop :existing, Blog::Types::Bool
          prop :named, Blog::Types::Bool

          def view_template
            status_button if @existing
            save_button
          end

          private

          def save_button
            Button(
              variant: :pri, type: "submit", disabled: !@named, icon: :save,
              data: { editor_save: "" },
            ) { t(@existing ? ".save" : ".create") }
          end

          def status_button
            *, icon, variant = @archived ? Row::RESTORE : Row::ARCHIVE
            Button(type: "submit", variant:, form: StatusForm::ID, icon:) { t(@archived ? ".restore" : ".archive") }
          end
        end
      end
    end
  end
end
