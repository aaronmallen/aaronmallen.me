# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class ContactSide < Component
          NEW_LABEL = "person-new_label"

          prop :values, Blog::Types::Hash
          prop :labels, Blog::Types::Array.of(Blog::Types::String)

          def view_template
            div(class: "stick contact-side") do
              Card(as: :aside, title: t(".labels")) { labels }
              Card(as: :aside, title: t(".starred")) do
                Checkbox(label: t(".favorite"), name: "person[starred]", checked: @values[:starred])
              end
            end
          end

          private

          def labels
            div(class: "search-kinds contact-picks", data: { contact_picks: "" }) do
              (@labels | @values[:labels]).sort.each { pick(it) }
            end
            div(class: "contact-new-label") do
              label(class: "sr-only", for: NEW_LABEL) { t(".new_label") }
              Input(id: NEW_LABEL, name: "person[new_label]", placeholder: t(".new_label"),
                    data: { contact_label_input: "" })
              Button(small: true, data: { contact_label_add: "" }) { t(".add_label") }
            end
            Hint { t(".labels_hint") }
          end

          def pick(name)
            label(class: "search-kind contact-pick") do
              input(type: "checkbox", class: "sr-only", name: "person[labels][]", value: name,
                    checked: @values[:labels].include?(name))
              plain "##{name}"
            end
          end
        end
      end
    end
  end
end
