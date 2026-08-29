# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class EditorActions < Component
          DRAFT = Blog::Types::PostIntent["draft"]
          PUBLISH = Blog::Types::PostIntent["publish"]
          SAVE = Blog::Types::PostIntent["save"]

          prop :deletable, Blog::Types::Bool
          prop :published, Blog::Types::Bool
          prop :scheduling, Blog::Types::Bool

          def view_template
            div(class: "page-head-actions") do
              delete_button if @deletable
              @published ? save_button : draft_and_publish_buttons
            end
          end

          private

          def button_label(icon, text_key, **)
            span(class: "btn-label", **) do
              i(class: icon, aria: { hidden: "true" })
              span { t(text_key) }
            end
          end

          def delete_button
            Button(variant: :warn, type: "submit", form: DeleteForm::ID) do
              button_label("fa-regular fa-trash-can", ".delete")
            end
          end

          def draft_and_publish_buttons
            Button(type: "submit", name: "intent", value: DRAFT) do
              button_label("fa-regular fa-floppy-disk", ".save_draft")
            end
            Button(variant: :pri, type: "submit", name: "intent", value: PUBLISH) do
              later = @scheduling
              button_label(
                "fa-solid fa-arrow-up-right-from-square", ".publish", data: { editor_now: "" }, hidden: later,
              )
              button_label("fa-regular fa-clock", ".schedule", data: { editor_later: "" }, hidden: !later)
            end
          end

          def save_button
            Button(variant: :pri, type: "submit", name: "intent", value: SAVE) do
              button_label("fa-regular fa-floppy-disk", ".save")
            end
          end
        end
      end
    end
  end
end
