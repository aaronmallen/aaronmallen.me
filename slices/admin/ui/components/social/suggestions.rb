# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Suggestions < Component
          prop :social_post_id, Blog::Types::Integer
          prop :parts, Blog::Types::Integer
          prop :edits, Blog::Types::Array.of(Blog::Types::Hash)
          prop :filter, Blog::Types::String

          def view_template
            Form(action: accept_path, data: { social_suggestions: "" }) do
              input(type: "hidden", name: "filter", value: @filter)
              Card(label: t(".heading")) do |card|
                card.side { bulk_actions }
                div(class: "sg-edits") { @edits.each { suggestion(it) } }
              end
            end
          end

          private

          def accept_path = path(:admin_accept_social_suggestions, id: @social_post_id)

          def actions(edit)
            div(class: "sg-actions") do
              next dismissal(edit) if edit[:stale]
              next refusal(edit) if edit[:over]

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
              del(class: "sg-before") { edit[:original] }
              ins(class: "sg-after") { edit[:replacement] }
            end
          end

          def dismissal(edit)
            Pill(color: :sand) { t(".stale") }
            Button(small: true, **submit(edit, reject: true)) { t(".dismiss") }
          end

          def part_label(edit)
            p(class: "sg-part") { t(".part", number: edit[:part]) } if @parts > 1
          end

          def refusal(edit)
            Pill(color: :orange) { t(".over_limit", limit: edit[:over].limit, network: edit[:over].label) }
            Button(small: true, **submit(edit, reject: true)) { t(".reject") }
          end

          def submit(edit = nil, reject: false)
            route = reject ? :admin_reject_social_suggestions : :admin_accept_social_suggestions
            chosen = { name: "edit_id", value: edit[:id] } if edit

            { type: "submit", formaction: path(route, id: @social_post_id), **chosen.to_h }
          end

          def suggestion(edit)
            div(class: "sg-edit") do
              part_label(edit)
              diff(edit)
              p(class: "sg-reason") { edit[:reason] }
              actions(edit)
            end
          end
        end
      end
    end
  end
end
