# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class NoteCard < Component
          BODY_HEIGHT = "260px"
          FORM_ID = "review-note-form"
          MONTH = Blog::Types::ReviewPeriod["month"]
          SCOPE = "review-note"

          prop :body, Blog::Types::String
          prop :saved, Blog::Types::Bool
          prop :errors, Blog::Types::Hash
          prop :period, Blog::Types::ReviewPeriod
          prop :to, Blog::Types::Date

          def view_template
            Card(title: t(".title"), id: "review-notes", class: "jbox review-notes") do |card|
              card.side { private_note }
              Form(id: FORM_ID, action: path(:admin_save_review_note)) do
                hidden_fields
                body_field
                foot
              end
            end
          end

          private

          def body_field
            div(class: "journal-editor") { MarkdownEditor(**body_props) }
            Journal::FieldError(field: :body, errors: @errors, scope: SCOPE)
          end

          def body_props
            {
              **Journal::FieldError.control_attributes(:body, @errors, SCOPE),
              name: "note[body]", value: @body, height: BODY_HEIGHT, renderer: "posts", label: t(".body"),
              placeholder: t(".placeholder"),
            }
          end

          def foot
            div(class: "jbox-foot") do
              span(class: "journal-words") { t(@saved ? ".saved" : ".unsaved") }
              span(class: "journal-words") { t(".filed", day: l(@to, format: :medium)) }
              save_button
            end
          end

          def hidden_fields
            input(type: "hidden", name: "period", value: @period) if @period == MONTH
            input(type: "hidden", name: "day", value: @to.iso8601)
          end

          def private_note
            span(class: "journal-words") do
              Icon("fa-solid fa-lock")
              plain " #{t('.private')}"
            end
          end

          def save_button
            Button(variant: :pri, small: true, type: "submit", icon: "fa-regular fa-floppy-disk") do
              t(@saved ? ".update" : ".save")
            end
          end
        end
      end
    end
  end
end
