# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Suggestions < Component
          ID = "post-suggestions"
          DIALOG = { id: ID, title_id: "#{ID}-title", hidden: false }.freeze

          prop :body, Blog::Types::String
          prop :edits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :review, Blog::Types::Bool

          def view_template
            Dialog(**DIALOG, title: t(".heading"), data: { dialog: true, dialog_show: (true if @review) }) do |dialog|
              dialog.foot { bulk_actions }
              div(class: "sg-edits") { @edits.each { suggestion(it) } }
            end
          end

          private

          def actions(edit, stale)
            return Button(small: true, **submit(edit, reject: true)) { t(".dismiss") } if stale

            Button(variant: :pri, small: true, **submit(edit)) { t(".accept") }
            Button(small: true, **submit(edit, reject: true)) { t(".reject") }
          end

          def bulk_actions
            Button(variant: :pri, small: true, **submit) { t(".accept_all") }
            Button(small: true, **submit(reject: true)) { t(".reject_all") }
          end

          def stale?(edit) = edit.stale? || !edit.applies_to?(@body)

          def submit(edit = nil, reject: false)
            chosen = { name: "edit_id", value: edit.id } if edit

            { type: "submit", form: reject ? SuggestionForms::REJECT : SuggestionForms::ACCEPT, **chosen.to_h }
          end

          def suggestion(edit)
            stale = stale?(edit)

            SuggestionEdit(original: edit.original, replacement: edit.replacement, reason: edit.reason, stale:) do
              actions(edit, stale)
            end
          end
        end
      end
    end
  end
end
