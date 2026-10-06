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
              variant: :pri, type: "submit", disabled: !@named, icon: "fa-regular fa-floppy-disk",
              data: { editor_save: "" },
            ) { t(@existing ? ".save" : ".create") }
          end

          def status_button
            Button(
              type: "submit", variant: (:gh unless @archived), form: StatusForm::ID,
              icon: @archived ? "fa-solid fa-rotate-left" : "fa-solid fa-box-archive",
            ) { t(@archived ? ".restore" : ".archive") }
          end
        end
      end
    end
  end
end
