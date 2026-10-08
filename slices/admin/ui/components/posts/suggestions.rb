# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class Suggestions < Component
          ID = "post-suggestions"
          DIALOG = { id: ID, title_id: "#{ID}-title", hidden: false, data: { dialog: true } }.freeze

          prop :body, Blog::Types::String
          prop :edits, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Dialog(**DIALOG, title: t(".heading")) do |dialog|
              dialog.foot { bulk_actions }
              div(class: "sg-edits") { @edits.each { suggestion(it) } }
            end
          end

          private

          def actions(edit)
            div(class: "sg-actions") do
              next dismissal(edit) if stale?(edit)

              Button(variant: :pri, small: true, **submit(edit)) { t(".accept") }
              Button(small: true, **submit(edit, reject: true)) { t(".reject") }
            end
          end

          def bulk_actions
            Button(variant: :pri, small: true, **submit) { t(".accept_all") }
            Button(small: true, **submit(reject: true)) { t(".reject_all") }
          end

          def diff(edit)
            p(class: "sg-diff") do
              del(class: "sg-before") { edit.original }
              ins(class: "sg-after") { edit.replacement }
            end
          end

          def dismissal(edit)
            Pill(color: :sand) { t(".stale") }
            Button(small: true, **submit(edit, reject: true)) { t(".dismiss") }
          end

          def stale?(edit) = edit.stale? || !edit.applies_to?(@body)

          def submit(edit = nil, reject: false)
            chosen = { name: "edit_id", value: edit.id } if edit

            { type: "submit", form: reject ? SuggestionForms::REJECT : SuggestionForms::ACCEPT, **chosen.to_h }
          end

          def suggestion(edit)
            div(class: "sg-edit") do
              diff(edit)
              p(class: "sg-reason") { edit.reason }
              actions(edit)
            end
          end
        end
      end
    end
  end
end
