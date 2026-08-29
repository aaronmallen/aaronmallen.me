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
            div(class: "page-head-actions") do
              status_button if @existing
              save_button
            end
          end

          private

          def button_label(icon, text_key)
            span(class: "btn-label") do
              i(class: icon, aria: { hidden: "true" })
              span { t(text_key) }
            end
          end

          def save_button
            Button(variant: :pri, type: "submit", disabled: !@named, data: { editor_save: "" }) do
              button_label("fa-regular fa-floppy-disk", @existing ? ".save" : ".create")
            end
          end

          def status_button
            Button(type: "submit", variant: (:gh unless @archived), form: StatusForm::ID) do
              next button_label("fa-solid fa-rotate-left", ".restore") if @archived

              button_label("fa-solid fa-box-archive", ".archive")
            end
          end
        end
      end
    end
  end
end
